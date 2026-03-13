-- ============================================================================
-- GiftPlan – Cron d'archivage automatique des listes
-- À adapter avec l'URL réelle de l'Edge Function et la clé service role.
-- ============================================================================

-- Exemple de planification quotidienne à 03h00 du matin (UTC) avec pg_cron.
-- Remplace :
--   - YOUR_PROJECT_REF par le ref Supabase (xxxxxx.supabase.co)
--   - YOUR_SERVICE_ROLE_KEY par la clé service role (à stocker plutôt
--     dans une variable de configuration sécurisée côté Supabase).

-- select
--   cron.schedule(
--     'archive_expired_lists_daily',
--     '0 3 * * *',
--     $$
--     select
--       net.http_post(
--         url := 'https://YOUR_PROJECT_REF.functions.supabase.co/archive-expired-lists',
--         body := '{}'::jsonb,
--         headers := jsonb_build_object(
--           'Content-Type', 'application/json',
--           'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
--         )
--       );
--     $$
--   );

-- ============================================================================
-- Fin du script (modèle, à adapter dans le SQL Editor Supabase)
-- ============================================================================

