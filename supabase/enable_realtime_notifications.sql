-- GP-19 : activer Realtime sur `notifications` (à exécuter une fois dans le SQL Editor Supabase si besoin).
-- Tableau Database > Publications ou :
alter publication supabase_realtime add table notifications;
