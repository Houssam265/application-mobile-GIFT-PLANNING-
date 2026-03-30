ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS action VARCHAR(50),
  ADD COLUMN IF NOT EXISTS liste_id UUID,
  ADD COLUMN IF NOT EXISTS produit_id UUID,
  ADD COLUMN IF NOT EXISTS suggestion_id UUID;

ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS fk_notification_liste,
  ADD CONSTRAINT fk_notification_liste
    FOREIGN KEY (liste_id) REFERENCES public.listes(id) ON DELETE CASCADE;

ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS fk_notification_produit,
  ADD CONSTRAINT fk_notification_produit
    FOREIGN KEY (produit_id) REFERENCES public.produits(id) ON DELETE CASCADE;

ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS fk_notification_suggestion,
  ADD CONSTRAINT fk_notification_suggestion
    FOREIGN KEY (suggestion_id) REFERENCES public.suggestions(id) ON DELETE CASCADE;

ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS type_notification_check,
  ADD CONSTRAINT type_notification_check
    CHECK (type IN ('FINANCEMENT', 'ARCHIVAGE', 'SUGGESTION', 'RAPPEL', 'CONTRIBUTION', 'ADHESION', 'PRODUIT'));

CREATE INDEX IF NOT EXISTS idx_notifications_liste ON public.notifications(liste_id);
CREATE INDEX IF NOT EXISTS idx_notifications_produit ON public.notifications(produit_id);
