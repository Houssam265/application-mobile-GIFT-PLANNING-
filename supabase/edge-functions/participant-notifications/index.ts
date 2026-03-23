import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

type Action = 'join_request' | 'join_accepted' | 'join_refused'

type Json =
  | null
  | boolean
  | number
  | string
  | Json[]
  | { [key: string]: Json }

function jsonResponse(body: Json, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

function getRequiredEnv(name: string) {
  const v = Deno.env.get(name)
  if (!v) throw new Error(`Missing ${name}`)
  return v
}

async function sendOneSignalPush(args: {
  oneSignalAppId: string
  oneSignalRestApiKey: string
  externalUserId: string
  headings: string
  contents: string
  data: Record<string, Json>
}) {
  const res = await fetch('https://onesignal.com/api/v1/notifications', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      Authorization: `Basic ${args.oneSignalRestApiKey}`,
    },
    body: JSON.stringify({
      app_id: args.oneSignalAppId,
      include_external_user_ids: [args.externalUserId],
      headings: { en: args.headings, fr: args.headings },
      contents: { en: args.contents, fr: args.contents },
      data: args.data,
    }),
  })

  const text = await res.text()
  if (!res.ok) {
    throw new Error(`OneSignal error (${res.status}): ${text}`)
  }
  try {
    return JSON.parse(text)
  } catch {
    return { raw: text }
  }
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') {
      return jsonResponse({ error: 'Method not allowed' }, 405)
    }

    const url = getRequiredEnv('SUPABASE_URL')
    const serviceRoleKey = getRequiredEnv('SUPABASE_SERVICE_ROLE_KEY')
    const oneSignalAppId = getRequiredEnv('ONESIGNAL_APP_ID')
    const oneSignalRestApiKey = getRequiredEnv('ONESIGNAL_REST_API_KEY')

    const authHeader = req.headers.get('Authorization') ?? ''
    const token = authHeader.startsWith('Bearer ')
      ? authHeader.substring('Bearer '.length).trim()
      : ''
    if (!token) {
      return jsonResponse({ error: 'Missing bearer token' }, 401)
    }

    const admin = createClient(url, serviceRoleKey)
    const {
      data: { user },
      error: authError,
    } = await admin.auth.getUser(token)
    if (authError || !user) {
      return jsonResponse({ error: 'Unauthorized' }, 401)
    }

    const body = await req.json().catch(() => ({} as any))
    const action = body?.action as Action | undefined
    const listId = body?.listId as string | undefined
    const participationId = body?.participationId as string | undefined

    if (!action || !listId) {
      return jsonResponse({ error: 'Missing action or listId' }, 400)
    }

    const { data: list, error: listErr } = await admin
      .from('listes')
      .select('id, titre, proprietaire_id')
      .eq('id', listId)
      .maybeSingle()

    if (listErr) return jsonResponse({ error: listErr.message }, 500)
    if (!list) return jsonResponse({ error: 'List not found' }, 404)

    const listTitle = (list as any).titre as string
    const ownerId = (list as any).proprietaire_id as string
    const requesterId = user.id

    if (action === 'join_request') {
      if (ownerId === requesterId) {
        return jsonResponse({ error: 'You are the list owner' }, 400)
      }

      const { data: existing, error: existingErr } = await admin
        .from('participations')
        .select('id, role')
        .eq('liste_id', listId)
        .eq('utilisateur_id', requesterId)
        .maybeSingle()
      if (existingErr) return jsonResponse({ error: existingErr.message }, 500)

      if (!existing) {
        const { error: insErr } = await admin.from('participations').insert({
          liste_id: listId,
          utilisateur_id: requesterId,
          role: 'EN_ATTENTE',
          date_adhesion: new Date().toISOString(),
        })
        if (insErr) return jsonResponse({ error: insErr.message }, 500)
      }

      const { data: reqUser } = await admin
        .from('utilisateurs')
        .select('nom')
        .eq('id', requesterId)
        .maybeSingle()
      const requesterName = (reqUser as any)?.nom ?? 'Un utilisateur'

      const message = `${requesterName} demande à rejoindre votre liste`
      await admin.from('notifications').insert({
        utilisateur_id: ownerId,
        type: 'ADHESION',
        message,
        est_lue: false,
        date_envoi: new Date().toISOString(),
      })

      await sendOneSignalPush({
        oneSignalAppId,
        oneSignalRestApiKey,
        externalUserId: ownerId,
        headings: 'Nouvelle demande',
        contents: `${requesterName} veut rejoindre « ${listTitle} »`,
        data: { event: 'join_request', listId, listTitle },
      })

      return jsonResponse({
        ok: true,
        status: (existing as any)?.role === 'INVITE' ? 'ALREADY_MEMBER' : 'PENDING',
      })
    }

    if (!participationId) {
      return jsonResponse({ error: 'Missing participationId' }, 400)
    }

    // Accept / refuse actions require owner permissions
    if (ownerId !== requesterId) {
      return jsonResponse({ error: 'Forbidden' }, 403)
    }

    const { data: participation, error: partErr } = await admin
      .from('participations')
      .select('id, liste_id, utilisateur_id, role')
      .eq('id', participationId)
      .eq('liste_id', listId)
      .maybeSingle()
    if (partErr) return jsonResponse({ error: partErr.message }, 500)
    if (!participation) return jsonResponse({ error: 'Participation not found' }, 404)

    const targetUserId = (participation as any).utilisateur_id as string
    const { data: targetUser } = await admin
      .from('utilisateurs')
      .select('nom')
      .eq('id', targetUserId)
      .maybeSingle()
    const targetName = (targetUser as any)?.nom ?? 'Votre demande'

    if (action === 'join_accepted') {
      const { error: updErr } = await admin
        .from('participations')
        .update({ role: 'INVITE' })
        .eq('id', participationId)
      if (updErr) return jsonResponse({ error: updErr.message }, 500)

      const msg = `Votre demande pour « ${listTitle} » a été acceptée.`
      await admin.from('notifications').insert({
        utilisateur_id: targetUserId,
        type: 'ADHESION',
        message: msg,
        est_lue: false,
        date_envoi: new Date().toISOString(),
      })

      await sendOneSignalPush({
        oneSignalAppId,
        oneSignalRestApiKey,
        externalUserId: targetUserId,
        headings: 'Demande acceptée',
        contents: `Vous pouvez accéder à « ${listTitle} ».`,
        data: { event: 'join_accepted', listId, listTitle },
      })

      return jsonResponse({ ok: true })
    }

    if (action === 'join_refused') {
      const { error: delErr } = await admin
        .from('participations')
        .delete()
        .eq('id', participationId)
      if (delErr) return jsonResponse({ error: delErr.message }, 500)

      const msg = `Votre demande pour « ${listTitle} » a été refusée.`
      await admin.from('notifications').insert({
        utilisateur_id: targetUserId,
        type: 'ADHESION',
        message: msg,
        est_lue: false,
        date_envoi: new Date().toISOString(),
      })

      await sendOneSignalPush({
        oneSignalAppId,
        oneSignalRestApiKey,
        externalUserId: targetUserId,
        headings: 'Demande refusée',
        contents: `Votre demande pour « ${listTitle} » a été refusée.`,
        data: { event: 'join_refused', listId, listTitle },
      })

      return jsonResponse({ ok: true })
    }

    return jsonResponse({ error: 'Unknown action' }, 400)
  } catch (e) {
    console.error(e)
    return jsonResponse({ error: String(e?.message ?? e) }, 500)
  }
})

