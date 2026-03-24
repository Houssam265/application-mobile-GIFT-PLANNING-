-- ==============================================================================
-- TABLE ET LOGIQUE POUR L'HISTORIQUE DES ACTIONS ADMIN (GIFTPLAN)
-- ==============================================================================

-- 1) Création de la table admin_logs
CREATE TABLE IF NOT EXISTS public.admin_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    action TEXT NOT NULL,           -- e.g., 'SUSPEND_USER', 'DELETE_USER', 'ARCHIVE_LIST', etc.
    target_id UUID NOT NULL,       -- ID de l'utilisateur ou de la liste concerné
    target_type TEXT NOT NULL,     -- 'USER' ou 'LIST'
    admin_id UUID NOT NULL,        -- ID de l'admin qui a fait l'action
    created_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT fk_admin FOREIGN KEY (admin_id) REFERENCES public.utilisateurs(id)
);

-- Index pour la pagination et les filtres
CREATE INDEX IF NOT EXISTS idx_admin_logs_action ON public.admin_logs(action);
CREATE INDEX IF NOT EXISTS idx_admin_logs_created_at ON public.admin_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_logs_target_type ON public.admin_logs(target_type);

-- 2) Mise à jour des fonctions RPC existantes pour inclure le logging

-- Mise à jour de admin_suspend_user
CREATE OR REPLACE FUNCTION admin_suspend_user(target_user_id UUID, is_suspended BOOLEAN)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    caller_is_admin BOOLEAN;
    log_action TEXT;
BEGIN
    SELECT est_administrateur INTO caller_is_admin 
    FROM public.utilisateurs 
    WHERE id = auth.uid();

    IF NOT caller_is_admin THEN
        RAISE EXCEPTION 'Accès refusé : Seuls les administrateurs peuvent suspendre des comptes.';
    END IF;

    UPDATE public.utilisateurs
    SET est_suspendu = is_suspended
    WHERE id = target_user_id;

    -- Logging
    log_action := CASE WHEN is_suspended THEN 'SUSPEND_USER' ELSE 'REACTIVATE_USER' END;
    INSERT INTO public.admin_logs (action, target_id, target_type, admin_id)
    VALUES (log_action, target_user_id, 'USER', auth.uid());

    RETURN TRUE;
END;
$$;

-- Mise à jour de admin_delete_user
CREATE OR REPLACE FUNCTION admin_delete_user(target_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    caller_is_admin BOOLEAN;
BEGIN
    SELECT est_administrateur INTO caller_is_admin 
    FROM public.utilisateurs 
    WHERE id = auth.uid();

    IF NOT caller_is_admin THEN
        RAISE EXCEPTION 'Accès refusé : Seuls les administrateurs peuvent supprimer des comptes.';
    END IF;

    IF target_user_id = auth.uid() THEN
        RAISE EXCEPTION 'Utilisez la fonction de suppression de votre propre compte profil.';
    END IF;

    -- On insère le log AVANT la suppression (car target_user_id pourrait être lié via FK si on loggait sur public.utilisateurs, mais ici on logge target_id comme UUID anonyme dans admin_logs)
    -- En fait, logguer target_id est sûr même si l'entité disparait, par contre l'admin_id doit rester.
    INSERT INTO public.admin_logs (action, target_id, target_type, admin_id)
    VALUES ('DELETE_USER', target_user_id, 'USER', auth.uid());

    DELETE FROM auth.users WHERE id = target_user_id;

    RETURN TRUE;
END;
$$;

-- Mise à jour de admin_update_list_status
CREATE OR REPLACE FUNCTION admin_update_list_status(target_list_id UUID, new_status VARCHAR)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    caller_is_admin BOOLEAN;
    log_action TEXT;
BEGIN
    SELECT est_administrateur INTO caller_is_admin 
    FROM public.utilisateurs 
    WHERE id = auth.uid();

    IF NOT caller_is_admin THEN
        RAISE EXCEPTION 'Accès refusé : Seuls les administrateurs peuvent modifier le statut d''une liste.';
    END IF;

    IF new_status NOT IN ('ACTIVE', 'ARCHIVEE') THEN
        RAISE EXCEPTION 'Statut invalide. Utilisez ACTIVE ou ARCHIVEE.';
    END IF;

    UPDATE public.listes
    SET statut = new_status,
        date_archivage = CASE WHEN new_status = 'ARCHIVEE' THEN CURRENT_TIMESTAMP ELSE NULL END
    WHERE id = target_list_id;

    -- Logging
    log_action := CASE WHEN new_status = 'ARCHIVEE' THEN 'ARCHIVE_LIST' ELSE 'REACTIVATE_LIST' END;
    INSERT INTO public.admin_logs (action, target_id, target_type, admin_id)
    VALUES (log_action, target_list_id, 'LIST', auth.uid());

    RETURN TRUE;
END;
$$;

-- Mise à jour de admin_delete_list
CREATE OR REPLACE FUNCTION admin_delete_list(target_list_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    caller_is_admin BOOLEAN;
BEGIN
    SELECT est_administrateur INTO caller_is_admin 
    FROM public.utilisateurs 
    WHERE id = auth.uid();

    IF NOT caller_is_admin THEN
        RAISE EXCEPTION 'Accès refusé : Seuls les administrateurs peuvent supprimer une liste.';
    END IF;

    -- Logging
    INSERT INTO public.admin_logs (action, target_id, target_type, admin_id)
    VALUES ('DELETE_LIST', target_list_id, 'LIST', auth.uid());

    DELETE FROM public.listes WHERE id = target_list_id;

    RETURN TRUE;
END;
$$;
