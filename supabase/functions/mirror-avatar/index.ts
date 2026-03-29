import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '86400',
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

function getRequiredEnv(name: string): string {
  const v = Deno.env.get(name)
  if (!v) throw new Error(`Missing env var: ${name}`)
  return v
}

/** Returns true if the URL belongs to a 3rd-party provider (not our own Supabase Storage). */
function isThirdPartyUrl(url: string, supabaseUrl: string): boolean {
  try {
    const host = new URL(url).hostname
    const ownHost = new URL(supabaseUrl).hostname
    return host !== ownHost
  } catch {
    return false
  }
}

Deno.serve(async (req) => {
  // CORS pre-flight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (req.method !== 'POST') {
      return jsonResponse({ error: 'Method not allowed' }, 405)
    }

    const supabaseUrl = getRequiredEnv('SUPABASE_URL')
    const anonKey = getRequiredEnv('SUPABASE_ANON_KEY')
    const serviceRoleKey = getRequiredEnv('SUPABASE_SERVICE_ROLE_KEY')

    // Authenticate the caller
    const authHeader = req.headers.get('Authorization') ?? ''
    const authed = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    })
    const { data: { user }, error: authError } = await authed.auth.getUser()
    if (authError || !user) {
      return jsonResponse({ error: 'Unauthorized' }, 401)
    }

    // Parse body
    const body = await req.json().catch(() => ({} as Record<string, unknown>))
    const thirdPartyUrl = body?.avatarUrl as string | undefined

    if (!thirdPartyUrl || typeof thirdPartyUrl !== 'string') {
      return jsonResponse({ error: 'Missing avatarUrl in body' }, 400)
    }

    // Safety: only mirror 3rd-party URLs, not our own storage
    if (!isThirdPartyUrl(thirdPartyUrl, supabaseUrl)) {
      return jsonResponse({ error: 'URL is already on Supabase Storage' }, 400)
    }

    const admin = createClient(supabaseUrl, serviceRoleKey)

    // Check if we already mirrored this user's avatar (idempotency)
    const { data: dbUser } = await admin
      .from('utilisateurs')
      .select('photo_profil_url')
      .eq('id', user.id)
      .maybeSingle()

    const existingUrl = (dbUser as { photo_profil_url?: string | null } | null)?.photo_profil_url ?? ''
    if (existingUrl && !isThirdPartyUrl(existingUrl, supabaseUrl)) {
      // Already mirrored — return the stored URL without re-uploading
      return jsonResponse({ publicUrl: existingUrl, cached: true })
    }

    // Fetch the remote image (with size guard: max 2 MB)
    const imageRes = await fetch(thirdPartyUrl)
    if (!imageRes.ok) {
      return jsonResponse({ error: `Failed to fetch avatar: ${imageRes.status}` }, 502)
    }
    const contentLength = imageRes.headers.get('content-length')
    if (contentLength && parseInt(contentLength, 10) > 2 * 1024 * 1024) {
      return jsonResponse({ error: 'Avatar image too large (> 2 MB)' }, 413)
    }
    const imageBuffer = await imageRes.arrayBuffer()
    if (imageBuffer.byteLength > 2 * 1024 * 1024) {
      return jsonResponse({ error: 'Avatar image too large (> 2 MB)' }, 413)
    }

    // Detect MIME type from Content-Type header; default to jpeg
    const rawContentType = imageRes.headers.get('content-type') ?? 'image/jpeg'
    const mimeType = rawContentType.split(';')[0].trim()
    const ext = mimeType === 'image/png' ? 'png' : mimeType === 'image/webp' ? 'webp' : 'jpg'

    // Upload to Supabase Storage using service role (bypasses RLS)
    const storagePath = `${user.id}/oauth_avatar.${ext}`
    const { error: uploadErr } = await admin.storage
      .from('avatars')
      .upload(storagePath, imageBuffer, {
        contentType: mimeType,
        upsert: true,
        cacheControl: '86400',
      })

    if (uploadErr) {
      return jsonResponse({ error: `Storage upload failed: ${uploadErr.message}` }, 500)
    }

    // Get the public URL
    const { data: { publicUrl } } = admin.storage.from('avatars').getPublicUrl(storagePath)

    // Update the utilisateurs table so the Flutter client picks it up
    const { error: updateErr } = await admin
      .from('utilisateurs')
      .update({ photo_profil_url: publicUrl })
      .eq('id', user.id)

    if (updateErr) {
      return jsonResponse({ error: `DB update failed: ${updateErr.message}` }, 500)
    }

    return jsonResponse({ publicUrl })
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    return jsonResponse({ error: message }, 500)
  }
})
