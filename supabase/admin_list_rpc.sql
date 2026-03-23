-- ==============================================================================
-- FONCTIONS RPC POUR LE TABLEAU DE BORD ADMINISTRATEUR (GIFTPLAN) - PARTIE LISTES
-- À exécuter dans le SQL Editor de votre projet Supabase
-- ==============================================================================

-- 1) Fonction pour forcer l'archivage ou la réactivation d'une liste
CREATE OR REPLACE FUNCTION admin_update_list_status(target_list_id UUID, new_status VARCHAR)
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
        RAISE EXCEPTION 'Accès refusé : Seuls les administrateurs peuvent modifier le statut d''une liste.';
    END IF;

    IF new_status NOT IN ('ACTIVE', 'ARCHIVEE') THEN
        RAISE EXCEPTION 'Statut invalide. Utilisez ACTIVE ou ARCHIVEE.';
    END IF;

    UPDATE public.listes
    SET statut = new_status,
        date_archivage = CASE WHEN new_status = 'ARCHIVEE' THEN CURRENT_TIMESTAMP ELSE NULL END
    WHERE id = target_list_id;

    RETURN TRUE;
END;
$$;


-- 2) Fonction pour supprimer complètement une liste (inappropriée)
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

    -- Supprimer la liste (les participations, produits, contributions seront supprimés en cascade selon la BDD)
    DELETE FROM public.listes WHERE id = target_list_id;

    RETURN TRUE;
END;
$$;
