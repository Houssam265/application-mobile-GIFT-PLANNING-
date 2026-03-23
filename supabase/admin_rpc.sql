-- ==============================================================================
-- FONCTIONS RPC POUR LE TABLEAU DE BORD ADMINISTRATEUR (GIFTPLAN)
-- À exécuter dans le SQL Editor de votre projet Supabase
-- ==============================================================================

-- 1) Fonction pour suspendre ou réactiver un utilisateur en toute sécurité
CREATE OR REPLACE FUNCTION admin_suspend_user(target_user_id UUID, is_suspended BOOLEAN)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER -- Permet à la fonction de s'exécuter avec les privilèges du créateur (contourne les RLS)
AS $$
DECLARE
    caller_is_admin BOOLEAN;
BEGIN
    -- 1. Vérifier si l'utilisateur qui appelle la fonction est réellement administrateur
    SELECT est_administrateur INTO caller_is_admin 
    FROM public.utilisateurs 
    WHERE id = auth.uid();

    IF NOT caller_is_admin THEN
        RAISE EXCEPTION 'Accès refusé : Seuls les administrateurs peuvent suspendre des comptes.';
    END IF;

    -- 2. Mettre à jour le statut dans la table utilisateurs
    UPDATE public.utilisateurs
    SET est_suspendu = is_suspended
    WHERE id = target_user_id;

    RETURN TRUE;
END;
$$;


-- 2) Fonction pour supprimer complètement un utilisateur de l'application
CREATE OR REPLACE FUNCTION admin_delete_user(target_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    caller_is_admin BOOLEAN;
BEGIN
    -- 1. Vérifier si l'utilisateur qui appelle la fonction est réellement administrateur
    SELECT est_administrateur INTO caller_is_admin 
    FROM public.utilisateurs 
    WHERE id = auth.uid();

    IF NOT caller_is_admin THEN
        RAISE EXCEPTION 'Accès refusé : Seuls les administrateurs peuvent supprimer des comptes.';
    END IF;

    -- 2. Interdire de se supprimer soi-même via cette fonction (sécurité)
    IF target_user_id = auth.uid() THEN
        RAISE EXCEPTION 'Utilisez la fonction de suppression de votre propre compte profil.';
    END IF;

    -- 3. Supprimer le compte de l'authentification Supabase (auth.users)
    -- Grâce au ON DELETE CASCADE, cela supprimera aussi la ligne dans public.utilisateurs
    DELETE FROM auth.users WHERE id = target_user_id;

    -- Note : si vous n'avez pas de cascade entre auth et utilisateurs, 
    -- décommentez la ligne ci-dessous :
    -- DELETE FROM public.utilisateurs WHERE id = target_user_id;

    RETURN TRUE;
END;
$$;
