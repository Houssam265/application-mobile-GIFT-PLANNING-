// GiftPlan – Alerte J-1 si le financement de la liste est incomplet (tous les participants).
// Déployer puis planifier en cron quotidien avec Authorization: Bearer SERVICE_ROLE_KEY.

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

function addDaysToIsoDate(isoDate: string, delta: number): string {
  const [y, m, d] = isoDate.split('-').map((x) => parseInt(x, 10))
  const dt = new Date(Date.UTC(y, m - 1, d + delta))
  return dt.toISOString().split('T')[0]
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
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST' && req.method !== 'GET') {
      return jsonResponse({ error: 'Method not allowed' }, 405)
    }

    const url = Deno.env.get('SUPABASE_URL') ?? ''
    const providedToken = req.headers.get('Authorization')?.replace('Bearer ', '').trim() ?? ''
    const oneSignalAppId = Deno.env.get('ONESIGNAL_APP_ID') ?? ''
    const oneSignalRestApiKey = Deno.env.get('ONESIGNAL_REST_API_KEY') ?? ''

    if (!url || !providedToken) {
      return jsonResponse({ error: 'Missing Supabase env or Authorization header' }, 401)
    }

    if (!oneSignalAppId || !oneSignalRestApiKey) {
      return jsonResponse({ error: 'Missing OneSignal env' }, 500)
    }

    const supabase = createClient(url, providedToken)

    const today = new Date().toISOString().split('T')[0]
    const in1 = addDaysToIsoDate(today, 1)

    const { data: lists, error: listErr } = await supabase
      .from('listes')
      .select('id, titre, proprietaire_id')
      .eq('statut', 'ACTIVE')
      .eq('date_evenement', in1)

    if (listErr) {
      console.error(listErr)
      return jsonResponse({ error: listErr.message }, 500)
    }

    let notificationsSent = 0
    const nowIso = new Date().toISOString()

    for (const row of lists ?? []) {
      const L = row as {
        id: string
        titre: string
        proprietaire_id: string
      }

      const { data: openProducts, error: prodErr } = await supabase
        .from('produits')
        .select('id')
        .eq('liste_id', L.id)
        .neq('statut_financement', 'FINANCE')

      if (!prodErr && openProducts && openProducts.length > 0) {
        const ownerId = L.proprietaire_id
        const n = openProducts.length
        const fundingMsg =
          `J-1 : votre liste « ${L.titre} » compte encore ${n} produit(s) non entièrement financé(s).`

        await supabase.from('notifications').insert({
          utilisateur_id: ownerId,
          type: 'FINANCEMENT',
          message: fundingMsg,
          est_lue: false,
          date_envoi: nowIso,
          action: 'funding_incomplete_j1',
          liste_id: L.id,
        })
        
        await sendOneSignalPush({
          oneSignalAppId,
          oneSignalRestApiKey,
          externalUserId: ownerId,
          headings: 'Financement incomplet',
          contents: fundingMsg,
          data: {
            event: 'funding_incomplete_j1',
            listId: L.id,
            listTitle: L.titre,
          },
        })
        notificationsSent++

        const fundingMsgInvites =
          `J-1 : La liste « ${L.titre} » compte encore ${n} produit(s) non entièrement financé(s).`

        const { data: parts, error: pErr } = await supabase
          .from('participations')
          .select('utilisateur_id')
          .eq('liste_id', L.id)
          .in('role', ['INVITE'])

        if (pErr) {
          console.error(pErr)
          continue
        }

        const userIds = new Set(
          ((parts ?? []) as { utilisateur_id: string }[]).map((p) => p.utilisateur_id),
        )

        for (const uid of userIds) {
          await supabase.from('notifications').insert({
            utilisateur_id: uid,
            type: 'FINANCEMENT',
            message: fundingMsgInvites,
            est_lue: false,
            date_envoi: nowIso,
            action: 'funding_incomplete_j1',
            liste_id: L.id,
          })

          await sendOneSignalPush({
            oneSignalAppId,
            oneSignalRestApiKey,
            externalUserId: uid,
            headings: 'Financement incomplet',
            contents: fundingMsgInvites,
            data: {
              event: 'funding_incomplete_j1',
              listId: L.id,
              listTitle: L.titre,
            },
          })
          notificationsSent++
        }
      }
    }

    return jsonResponse({
      ok: true,
      lists_checked: (lists ?? []).length,
      notifications_sent: notificationsSent,
    })
  } catch (e) {
    console.error(e)
    const err = e as { message?: string }
    return jsonResponse({ error: String(err?.message ?? e) }, 500)
  }
})
