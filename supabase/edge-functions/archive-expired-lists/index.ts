// @ts-nocheck
// GiftPlan – Edge Function d'archivage automatique des listes expirées
// À déployer sur Supabase (Edge Functions), puis planifier via un cron quotidien.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (_req) => {
  const url = Deno.env.get('SUPABASE_URL') ?? ''
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

  if (!url || !serviceRoleKey) {
    return new Response(
      JSON.stringify({ error: 'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }

  const supabase = createClient(url, serviceRoleKey)

  // On considère "24h après la date de l'événement" ≈ date_evenement < (today - 1 jour)
  const now = new Date()
  const threshold = new Date(now.getTime() - 24 * 60 * 60 * 1000)
  const thresholdIsoDate = threshold.toISOString().split('T')[0] // YYYY-MM-DD

  const nowIso = now.toISOString()

  const { data, error } = await supabase
    .from('listes')
    .update({
      statut: 'ARCHIVEE',
      date_archivage: nowIso,
      date_modification: nowIso,
    })
    .lte('date_evenement', thresholdIsoDate)
    .eq('statut', 'ACTIVE')
    .select('id')

  if (error) {
    console.error('Erreur archivage auto listes :', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  return new Response(
    JSON.stringify({
      archived_count: data?.length ?? 0,
      archived_ids: data?.map((row: { id: string }) => row.id) ?? [],
    }),
    {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    },
  )
})

