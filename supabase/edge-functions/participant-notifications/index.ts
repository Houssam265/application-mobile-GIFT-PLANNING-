import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

type Action =
  | 'join_request'
  | 'join_accepted'
  | 'join_refused'
  | 'suggestion_created'
  | 'suggestion_accepted'
  | 'suggestion_refused'
  | 'list_archived_notify'
  | 'contribution_received'
  | 'product_fully_funded'
  | 'product_funding_dropped'

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

async function sendOneSignalPush(admin: ReturnType<typeof createClient>, args: {
  oneSignalAppId: string
  oneSignalRestApiKey: string
  externalUserId: string
  headings: string
  contents: string
  data: Record<string, Json>
}) {
  let playerId: string | null = null
  try {
    const { data: u } = await admin
      .from('utilisateurs')
      .select('player_id')
      .eq('id', args.externalUserId)
      .maybeSingle()
    playerId = (u as { player_id?: string } | null)?.player_id ?? null
  } catch {}

  const body: Record<string, unknown> = {
    app_id: args.oneSignalAppId,
    include_external_user_ids: [args.externalUserId],
    headings: { en: args.headings, fr: args.headings },
    contents: { en: args.contents, fr: args.contents },
    data: args.data,
  }
  if (playerId && playerId.length > 0) {
    ;(body as { include_player_ids: string[] }).include_player_ids = [playerId]
  }

  const res = await fetch('https://onesignal.com/api/v1/notifications', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      Authorization: `Basic ${args.oneSignalRestApiKey}`,
    },
    body: JSON.stringify(body),
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
    const anonKey = getRequiredEnv('SUPABASE_ANON_KEY')
    const serviceRoleKey = getRequiredEnv('SUPABASE_SERVICE_ROLE_KEY')
    const oneSignalAppId = getRequiredEnv('ONESIGNAL_APP_ID')
    const oneSignalRestApiKey = getRequiredEnv('ONESIGNAL_REST_API_KEY')

    const authHeader = req.headers.get('Authorization') ?? ''
    const authed = createClient(url, anonKey, {
      global: { headers: { Authorization: authHeader } },
    })
    const {
      data: { user },
      error: authError,
    } = await authed.auth.getUser()
    if (authError || !user) {
      return jsonResponse({ error: 'Unauthorized' }, 401)
    }

    const admin = createClient(url, serviceRoleKey)

    const body = await req.json().catch(() => ({} as Record<string, unknown>))
    const action = body?.action as Action | undefined
    const listId = body?.listId as string | undefined
    const participationId = body?.participationId as string | undefined
    const suggestionId = body?.suggestionId as string | undefined
    const productId = body?.productId as string | undefined

    if (!action) {
      return jsonResponse({ error: 'Missing action' }, 400)
    }

    const requesterId = user.id

    // ── Suggestion : push uniquement (ligne notifications déjà insérée côté app) ──
    if (action === 'suggestion_created') {
      if (!listId || !suggestionId) {
        return jsonResponse({ error: 'Missing listId or suggestionId' }, 400)
      }

      const { data: list, error: listErr } = await admin
        .from('listes')
        .select('id, titre, proprietaire_id')
        .eq('id', listId)
        .maybeSingle()
      if (listErr) return jsonResponse({ error: listErr.message }, 500)
      if (!list) return jsonResponse({ error: 'List not found' }, 404)

      const listTitle = (list as { titre: string }).titre
      const ownerId = (list as { proprietaire_id: string }).proprietaire_id

      const { data: suggestion, error: sugErr } = await admin
        .from('suggestions')
        .select('id, liste_id, utilisateur_id, statut, nom_produit')
        .eq('id', suggestionId)
        .maybeSingle()
      if (sugErr) return jsonResponse({ error: sugErr.message }, 500)
      if (!suggestion) return jsonResponse({ error: 'Suggestion not found' }, 404)

      const s = suggestion as {
        liste_id: string
        utilisateur_id: string
        statut: string
        nom_produit: string
      }
      if (s.liste_id !== listId) {
        return jsonResponse({ error: 'Suggestion list mismatch' }, 400)
      }
      if (s.utilisateur_id !== requesterId) {
        return jsonResponse({ error: 'Forbidden' }, 403)
      }
      if (s.statut !== 'EN_ATTENTE') {
        return jsonResponse({ error: 'Invalid suggestion state' }, 400)
      }

      const { data: reqUser } = await admin
        .from('utilisateurs')
        .select('nom')
        .eq('id', requesterId)
        .maybeSingle()
      const requesterName = (reqUser as { nom?: string } | null)?.nom ?? 'Un participant'

      await sendOneSignalPush(admin, {
        oneSignalAppId,
        oneSignalRestApiKey,
        externalUserId: ownerId,
        headings: 'Nouvelle suggestion',
        contents: `${requesterName} propose « ${s.nom_produit} » sur « ${listTitle} »`,
        data: {
          event: 'suggestion_new',
          listId,
          listTitle,
          suggestionId,
        },
      })

      return jsonResponse({ ok: true })
    }

    if (action === 'suggestion_accepted' || action === 'suggestion_refused') {
      if (!listId || !suggestionId) {
        return jsonResponse({ error: 'Missing listId or suggestionId' }, 400)
      }

      const { data: list, error: listErr } = await admin
        .from('listes')
        .select('id, titre, proprietaire_id')
        .eq('id', listId)
        .maybeSingle()
      if (listErr) return jsonResponse({ error: listErr.message }, 500)
      if (!list) return jsonResponse({ error: 'List not found' }, 404)

      const listTitle = (list as { titre: string }).titre
      const ownerId = (list as { proprietaire_id: string }).proprietaire_id

      if (ownerId !== requesterId) {
        return jsonResponse({ error: 'Forbidden' }, 403)
      }

      const expectedStatut = action === 'suggestion_accepted' ? 'VALIDEE' : 'REFUSEE'

      const { data: suggestion, error: sugErr } = await admin
        .from('suggestions')
        .select('id, liste_id, utilisateur_id, statut, nom_produit')
        .eq('id', suggestionId)
        .maybeSingle()
      if (sugErr) return jsonResponse({ error: sugErr.message }, 500)
      if (!suggestion) return jsonResponse({ error: 'Suggestion not found' }, 404)

      const s = suggestion as {
        liste_id: string
        utilisateur_id: string
        statut: string
        nom_produit: string
      }
      if (s.liste_id !== listId) {
        return jsonResponse({ error: 'Suggestion list mismatch' }, 400)
      }
      if (s.statut !== expectedStatut) {
        return jsonResponse({ error: 'Invalid suggestion state' }, 400)
      }

      const suggesterId = s.utilisateur_id
      if (!suggesterId) {
        return jsonResponse({ error: 'No suggester' }, 400)
      }

      const event =
        action === 'suggestion_accepted' ? 'suggestion_accepted' : 'suggestion_refused'
      const headings =
        action === 'suggestion_accepted' ? 'Suggestion acceptée' : 'Suggestion refusée'
      const contents =
        action === 'suggestion_accepted'
          ? `« ${s.nom_produit} » a été ajouté à « ${listTitle} ».`
          : `« ${s.nom_produit} » n'a pas été retenue pour « ${listTitle} ».`

      await sendOneSignalPush(admin, {
        oneSignalAppId,
        oneSignalRestApiKey,
        externalUserId: suggesterId,
        headings,
        contents,
        data: { event, listId, listTitle, suggestionId },
      })

      return jsonResponse({ ok: true })
    }

    // ── Archivage manuel : notif in-app + push pour tous les participants ──
    if (action === 'list_archived_notify') {
      if (!listId) {
        return jsonResponse({ error: 'Missing listId' }, 400)
      }

      const { data: list, error: listErr } = await admin
        .from('listes')
        .select('id, titre, proprietaire_id, statut')
        .eq('id', listId)
        .maybeSingle()
      if (listErr) return jsonResponse({ error: listErr.message }, 500)
      if (!list) return jsonResponse({ error: 'List not found' }, 404)

      const L = list as {
        titre: string
        proprietaire_id: string
        statut: string
      }
      if (L.proprietaire_id !== requesterId) {
        return jsonResponse({ error: 'Forbidden' }, 403)
      }
      if (L.statut !== 'ARCHIVEE') {
        return jsonResponse({ error: 'List must be archived first' }, 400)
      }

      const { data: parts, error: pErr } = await admin
        .from('participations')
        .select('utilisateur_id')
        .eq('liste_id', listId)
      if (pErr) return jsonResponse({ error: pErr.message }, 500)

      const userIds = new Set(
        ((parts ?? []) as { utilisateur_id: string }[]).map((p) => p.utilisateur_id),
      )
      userIds.add(L.proprietaire_id)

      const message = `La liste « ${L.titre} » a été archivée.`
      const nowIso = new Date().toISOString()

      for (const uid of userIds) {
        await admin.from('notifications').insert({
          utilisateur_id: uid,
          type: 'ARCHIVAGE',
          message,
          est_lue: false,
          date_envoi: nowIso,
        })
        await sendOneSignalPush(admin, {
          oneSignalAppId,
          oneSignalRestApiKey,
          externalUserId: uid,
          headings: 'Liste archivée',
          contents: message,
          data: { event: 'list_archived', listId, listTitle: L.titre },
        })
      }

      return jsonResponse({ ok: true, notified: userIds.size })
    }

    // ── Contributions : push (lignes notifications souvent déjà insérées côté app) ──
    if (
      action === 'contribution_received' ||
      action === 'product_fully_funded' ||
      action === 'product_funding_dropped'
    ) {
      if (!listId || !productId) {
        return jsonResponse({ error: 'Missing listId or productId' }, 400)
      }

      let activeContrib: { id: string; montant: unknown } | null = null

      if (action === 'product_funding_dropped') {
        const { data: cancelled, error: cxErr } = await admin
          .from('contributions')
          .select('id, date_modification')
          .eq('produit_id', productId)
          .eq('utilisateur_id', requesterId)
          .eq('est_annulee', true)
          .order('date_modification', { ascending: false })
          .limit(1)
          .maybeSingle()

        if (cxErr) return jsonResponse({ error: cxErr.message }, 500)
        if (!cancelled) {
          return jsonResponse({ error: 'No cancelled contribution found' }, 403)
        }
        const dm = (cancelled as { date_modification?: string | null }).date_modification
        if (dm) {
          const t = new Date(dm).getTime()
          if (Number.isFinite(t) && Date.now() - t > 5 * 60 * 1000) {
            return jsonResponse({ error: 'Contribution cancel too old' }, 403)
          }
        }
      } else {
        const { data: ac, error: acErr } = await admin
          .from('contributions')
          .select('id, montant')
          .eq('produit_id', productId)
          .eq('utilisateur_id', requesterId)
          .eq('est_annulee', false)
          .maybeSingle()

        if (acErr) return jsonResponse({ error: acErr.message }, 500)
        if (!ac) {
          return jsonResponse({ error: 'No active contribution for this product' }, 403)
        }
        activeContrib = ac as { id: string; montant: unknown }
      }

      const { data: product, error: prodErr } = await admin
        .from('produits')
        .select('nom, liste_id, statut_financement')
        .eq('id', productId)
        .maybeSingle()
      if (prodErr) return jsonResponse({ error: prodErr.message }, 500)
      if (!product) return jsonResponse({ error: 'Product not found' }, 404)

      const p = product as {
        nom: string
        liste_id: string
        statut_financement: string
      }
      if (p.liste_id !== listId) {
        return jsonResponse({ error: 'Product list mismatch' }, 400)
      }

      const { data: listRow, error: l2Err } = await admin
        .from('listes')
        .select('proprietaire_id, titre')
        .eq('id', listId)
        .maybeSingle()
      if (l2Err) return jsonResponse({ error: l2Err.message }, 500)
      if (!listRow) return jsonResponse({ error: 'List not found' }, 404)

      const ownerId = (listRow as { proprietaire_id: string }).proprietaire_id
      const listTitle = (listRow as { titre: string }).titre

      if (action === 'contribution_received') {
        if (!activeContrib) {
          return jsonResponse({ error: 'Internal state' }, 500)
        }
        if (ownerId === requesterId) {
          return jsonResponse({ ok: true, skipped: true })
        }

        const montantRaw = activeContrib.montant
        const montant =
          typeof montantRaw === 'number'
            ? montantRaw
            : parseFloat(String(montantRaw ?? '0'))

        const { data: reqUser } = await admin
          .from('utilisateurs')
          .select('nom')
          .eq('id', requesterId)
          .maybeSingle()
        const who = (reqUser as { nom?: string } | null)?.nom ?? 'Un participant'

        await sendOneSignalPush({
          oneSignalAppId,
          oneSignalRestApiKey,
          externalUserId: ownerId,
          headings: 'Nouvelle promesse',
          contents: `${who} a promis ${montant.toFixed(2)}€ pour « ${p.nom} » (${listTitle}).`,
          data: {
            event: 'contribution_new',
            listId,
            listTitle,
            productId,
          },
        })
        return jsonResponse({ ok: true })
      }

      if (action === 'product_fully_funded') {
        if (p.statut_financement !== 'FINANCE') {
          return jsonResponse({ error: 'Product not fully funded' }, 400)
        }

        await sendOneSignalPush(admin, {
          oneSignalAppId,
          oneSignalRestApiKey,
          externalUserId: ownerId,
          headings: 'Objectif atteint',
          contents: `« ${p.nom} » est entièrement financé sur « ${listTitle} » !`,
          data: {
            event: 'product_fully_funded',
            listId,
            listTitle,
            productId,
          },
        })
        return jsonResponse({ ok: true })
      }

      // product_funding_dropped
      await sendOneSignalPush(admin, {
        oneSignalAppId,
        oneSignalRestApiKey,
        externalUserId: ownerId,
        headings: 'Financement mis à jour',
        contents: `« ${p.nom} » n'est plus entièrement financé sur « ${listTitle} ».`,
        data: {
          event: 'product_funding_dropped',
          listId,
          listTitle,
          productId,
        },
      })
      return jsonResponse({ ok: true })
    }

    // ── Adhésions (listId requis) ──
    if (!listId) {
      return jsonResponse({ error: 'Missing listId' }, 400)
    }

    const { data: list, error: listErr } = await admin
      .from('listes')
      .select('id, titre, proprietaire_id')
      .eq('id', listId)
      .maybeSingle()

    if (listErr) return jsonResponse({ error: listErr.message }, 500)
    if (!list) return jsonResponse({ error: 'List not found' }, 404)

    const listTitle = (list as { titre: string }).titre
    const ownerId = (list as { proprietaire_id: string }).proprietaire_id

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
      const requesterName = (reqUser as { nom?: string } | null)?.nom ?? 'Un utilisateur'

      const message = `${requesterName} demande à rejoindre votre liste`
      await admin.from('notifications').insert({
        utilisateur_id: ownerId,
        type: 'ADHESION',
        message,
        est_lue: false,
        date_envoi: new Date().toISOString(),
      })

      await sendOneSignalPush(admin, {
        oneSignalAppId,
        oneSignalRestApiKey,
        externalUserId: ownerId,
        headings: 'Nouvelle demande',
        contents: `${requesterName} veut rejoindre « ${listTitle} »`,
        data: { event: 'join_request', listId, listTitle },
      })

      return jsonResponse({
        ok: true,
        status: (existing as { role?: string } | null)?.role === 'INVITE'
          ? 'ALREADY_MEMBER'
          : 'PENDING',
      })
    }

    if (!participationId) {
      return jsonResponse({ error: 'Missing participationId' }, 400)
    }

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

    const targetUserId = (participation as { utilisateur_id: string }).utilisateur_id

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

      await sendOneSignalPush(admin, {
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

      await sendOneSignalPush(admin, {
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
    const err = e as { message?: string }
    return jsonResponse({ error: String(err?.message ?? e) }, 500)
  }
})
