-- ============================================================================
-- GiftPlan – Synchronisation auth.users -> public.utilisateurs
-- À exécuter une fois dans le SQL Editor Supabase pour ce projet.
-- ============================================================================

-- 1) Fonction qui crée automatiquement une entrée dans public.utilisateurs
--    à chaque création de user dans auth.users.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.utilisateurs (id, nom, email, mot_de_passe_hash)
  values (
    new.id,  -- même UUID que auth.users.id
    coalesce(new.raw_user_meta_data->>'nom', split_part(new.email, '@', 1)),
    new.email,
    'supabase-auth-managed'  -- valeur factice, non utilisée par Supabase Auth
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

-- 2) Trigger sur la table système auth.users
drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_auth_user();

-- 3) Backfill : créer les entrées manquantes dans public.utilisateurs
--    pour les utilisateurs déjà présents dans auth.users.
insert into public.utilisateurs (id, nom, email, mot_de_passe_hash)
select
  u.id,
  coalesce(u.raw_user_meta_data->>'nom', split_part(u.email, '@', 1)) as nom,
  u.email,
  'supabase-auth-managed'
from auth.users u
left join public.utilisateurs lu on lu.id = u.id
where lu.id is null;

-- 4) (Optionnel) Activer RLS sur public.utilisateurs et limiter chaque user
--    à sa propre ligne.
alter table public.utilisateurs enable row level security;

drop policy if exists "utilisateurs_select_own" on public.utilisateurs;
drop policy if exists "utilisateurs_update_own" on public.utilisateurs;

create policy "utilisateurs_select_own"
on public.utilisateurs
for select
using (id = auth.uid());

create policy "utilisateurs_update_own"
on public.utilisateurs
for update
using (id = auth.uid());

-- ============================================================================
-- Fin du script
-- ============================================================================

