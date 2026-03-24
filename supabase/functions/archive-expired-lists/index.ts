// GiftPlan – Archivage auto + notifications ARCHIVAGE + push OneSignal.
// Cron quotidien : Authorization: Bearer SERVICE_ROLE_KEY

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

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
    console.error('OneSignal:', res.status, text)
  }
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST' && req.method !== 'GET') {
      return jsonResponse({ error: 'Method not allowed' }, 405)
    }

    const url = Deno.env.get('SUPABASE_URL') ?? ''
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const oneSignalAppId = Deno.env.get('ONESIGNAL_APP_ID') ?? ''
    const oneSignalRestApiKey = Deno.env.get('ONESIGNAL_REST_API_KEY') ?? ''

    if (!url || !serviceRoleKey) {
      return jsonResponse({ error: 'Missing Supabase env' }, 500)
    }

    const authHeader = req.headers.get('Authorization') ?? ''
    if (authHeader !== `Bearer ${serviceRoleKey}`) {
      return jsonResponse({ error: 'Unauthorized' }, 401)
    }

    const supabase = createClient(url, serviceRoleKey)

    const now = new Date()
    const threshold = new Date(now.getTime() - 24 * 60 * 60 * 1000)
    const thresholdIsoDate = threshold.toISOString().split('T')[0]
    const nowIso = now.toISOString()

    const { data: archivedRows, error } = await supabase
      .from('listes')
      .update({
        statut: 'ARCHIVEE',
        date_archivage: nowIso,
        date_modification: nowIso,
      })
      .lte('date_evenement', thresholdIsoDate)
      .eq('statut', 'ACTIVE')
      .select('id, titre, proprietaire_id')

    if (error) {
      console.error('Erreur archivage auto listes :', error)
      return jsonResponse({ error: error.message }, 500)
    }

    const rows = (archivedRows ?? []) as {
      id: string
      titre: string
      proprietaire_id: string
    }[]
    let pushAttempts = 0

    if (oneSignalAppId && oneSignalRestApiKey) {
      for (const L of rows) {
        const message =
          `La liste « ${L.titre} » a été archivée automatiquement après la date de l'événement.`

        const { data: parts } = await supabase
          .from('participations')
          .select('utilisateur_id')
          .eq('liste_id', L.id)

        const userIds = new Set(
          ((parts ?? []) as { utilisateur_id: string }[]).map((p) => p.utilisateur_id),
        )
        userIds.add(L.proprietaire_id)

        for (const uid of userIds) {
          await supabase.from('notifications').insert({
            utilisateur_id: uid,
            type: 'ARCHIVAGE',
            message,
            est_lue: false,
            date_envoi: nowIso,
          })
          await sendOneSignalPush({
            oneSignalAppId,
            oneSignalRestApiKey,
            externalUserId: uid,
            headings: 'Liste archivée',
            contents: message,
            data: {
              event: 'list_auto_archived',
              listId: L.id,
              listTitle: L.titre,
            },
          })
          pushAttempts++
        }
      }
    } else {
      console.warn('OneSignal non configuré : notifications in-app seulement')
      for (const L of rows) {
        const message =
          `La liste « ${L.titre} » a été archivée automatiquement après la date de l'événement.`
        const { data: parts } = await supabase
          .from('participations')
          .select('utilisateur_id')
          .eq('liste_id', L.id)
        const userIds = new Set(
          ((parts ?? []) as { utilisateur_id: string }[]).map((p) => p.utilisateur_id),
        )
        userIds.add(L.proprietaire_id)
        for (const uid of userIds) {
          await supabase.from('notifications').insert({
            utilisateur_id: uid,
            type: 'ARCHIVAGE',
            message,
            est_lue: false,
            date_envoi: nowIso,
          })
        }
      }
    }

    return jsonResponse({
      archived_count: rows.length,
      archived_ids: rows.map((r) => r.id),
      push_attempts: pushAttempts,
    })
  } catch (e) {
    console.error(e)
    const err = e as { message?: string }
    return jsonResponse({ error: String(err?.message ?? e) }, 500)
  }
})
