-- ============================================================================
-- GiftPlan Database Schema
-- PostgreSQL Script
-- Module: Développement Mobile (Flutter/Dart + Supabase)
-- Année Universitaire: 2025-2026
-- ============================================================================

-- Drop tables if they exist (in reverse order of dependencies)
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS contributions CASCADE;
DROP TABLE IF EXISTS suggestions CASCADE;
DROP TABLE IF EXISTS produits CASCADE;
DROP TABLE IF EXISTS participations CASCADE;
DROP TABLE IF EXISTS listes CASCADE;
DROP TABLE IF EXISTS utilisateurs CASCADE;

-- ============================================================================
-- TABLE: utilisateurs
-- ============================================================================
CREATE TABLE utilisateurs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nom VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    mot_de_passe_hash VARCHAR(255) NOT NULL,
    photo_profil_url TEXT,
    est_suspendu BOOLEAN DEFAULT FALSE,
    est_administrateur BOOLEAN DEFAULT FALSE,
    date_inscription TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_derniere_connexion TIMESTAMP,
    CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- ============================================================================
-- TABLE: listes
-- ============================================================================
CREATE TABLE listes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    titre VARCHAR(200) NOT NULL,
    description TEXT,
    nom_evenement VARCHAR(200) NOT NULL,
    date_evenement DATE NOT NULL,
    photo_couverture_url TEXT,
    lien_partage VARCHAR(100) UNIQUE NOT NULL,
    code_partage VARCHAR(20) UNIQUE NOT NULL,
    visibilite_contributions VARCHAR(20) NOT NULL DEFAULT 'PUBLIC',
    statut VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    proprietaire_id UUID NOT NULL,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_modification TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_archivage TIMESTAMP,
    CONSTRAINT fk_proprietaire FOREIGN KEY (proprietaire_id) REFERENCES utilisateurs(id) ON DELETE CASCADE,
    CONSTRAINT visibilite_check CHECK (visibilite_contributions IN ('PUBLIC', 'PRIVE', 'ANONYME')),
    CONSTRAINT statut_check CHECK (statut IN ('ACTIVE', 'ARCHIVEE'))
);

-- ============================================================================
-- TABLE: participations
-- ============================================================================
CREATE TABLE participations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    liste_id UUID NOT NULL,
    utilisateur_id UUID NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'EN_ATTENTE',
    date_adhesion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_liste FOREIGN KEY (liste_id) REFERENCES listes(id) ON DELETE CASCADE,
    CONSTRAINT fk_utilisateur FOREIGN KEY (utilisateur_id) REFERENCES utilisateurs(id) ON DELETE CASCADE,
    CONSTRAINT role_check CHECK (role IN ('PROPRIETAIRE', 'INVITE', 'EN_ATTENTE')),
    CONSTRAINT unique_participation UNIQUE (liste_id, utilisateur_id)
);

-- ============================================================================
-- TABLE: produits
-- ============================================================================
CREATE TABLE produits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    liste_id UUID NOT NULL,
    nom VARCHAR(200) NOT NULL,
    description TEXT,
    prix_cible DECIMAL(10, 2) NOT NULL,
    image_url TEXT,
    lien_url TEXT,
    categorie VARCHAR(20),
    statut_financement VARCHAR(30) NOT NULL DEFAULT 'NON_FINANCE',
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_modification TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_liste_produit FOREIGN KEY (liste_id) REFERENCES listes(id) ON DELETE CASCADE,
    CONSTRAINT prix_positif CHECK (prix_cible > 0),
    CONSTRAINT categorie_check CHECK (categorie IN ('TECH', 'MODE', 'MAISON', 'SPORT', 'AUTRE')),
    CONSTRAINT statut_financement_check CHECK (statut_financement IN ('NON_FINANCE', 'PARTIELLEMENT_FINANCE', 'FINANCE'))
);

-- ============================================================================
-- TABLE: suggestions
-- ============================================================================
CREATE TABLE suggestions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    liste_id UUID NOT NULL,
    utilisateur_id UUID NOT NULL,
    nom_produit VARCHAR(200) NOT NULL,
    description TEXT,
    prix_cible DECIMAL(10, 2) NOT NULL,
    image_url TEXT,
    lien_url TEXT,
    categorie VARCHAR(20),
    statut VARCHAR(20) NOT NULL DEFAULT 'EN_ATTENTE',
    motif_refus TEXT,
    date_suggestion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_traitement TIMESTAMP,
    CONSTRAINT fk_liste_suggestion FOREIGN KEY (liste_id) REFERENCES listes(id) ON DELETE CASCADE,
    CONSTRAINT fk_utilisateur_suggestion FOREIGN KEY (utilisateur_id) REFERENCES utilisateurs(id) ON DELETE CASCADE,
    CONSTRAINT prix_suggestion_positif CHECK (prix_cible > 0),
    CONSTRAINT statut_suggestion_check CHECK (statut IN ('EN_ATTENTE', 'VALIDEE', 'REFUSEE'))
);

-- ============================================================================
-- TABLE: contributions
-- ============================================================================
CREATE TABLE contributions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    produit_id UUID NOT NULL,
    utilisateur_id UUID NOT NULL,
    montant DECIMAL(10, 2) NOT NULL,
    est_annulee BOOLEAN DEFAULT FALSE,
    date_promesse TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_modification TIMESTAMP,
    CONSTRAINT fk_produit FOREIGN KEY (produit_id) REFERENCES produits(id) ON DELETE CASCADE,
    CONSTRAINT fk_utilisateur_contribution FOREIGN KEY (utilisateur_id) REFERENCES utilisateurs(id) ON DELETE CASCADE,
    CONSTRAINT montant_positif CHECK (montant >= 1)
);

-- ============================================================================
-- TABLE: notifications
-- ============================================================================
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    utilisateur_id UUID NOT NULL,
    type VARCHAR(30) NOT NULL,
    message TEXT NOT NULL,
    est_lue BOOLEAN DEFAULT FALSE,
    date_envoi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_utilisateur_notification FOREIGN KEY (utilisateur_id) REFERENCES utilisateurs(id) ON DELETE CASCADE,
    CONSTRAINT type_notification_check CHECK (type IN ('FINANCEMENT', 'ARCHIVAGE', 'SUGGESTION', 'RAPPEL', 'CONTRIBUTION', 'ADHESION'))
);

-- ============================================================================
-- INDEXES for better performance
-- ============================================================================
CREATE INDEX idx_listes_proprietaire ON listes(proprietaire_id);
CREATE INDEX idx_listes_statut ON listes(statut);
CREATE INDEX idx_listes_date_evenement ON listes(date_evenement);
CREATE INDEX idx_participations_liste ON participations(liste_id);
CREATE INDEX idx_participations_utilisateur ON participations(utilisateur_id);
CREATE INDEX idx_produits_liste ON produits(liste_id);
CREATE INDEX idx_contributions_produit ON contributions(produit_id);
CREATE INDEX idx_contributions_utilisateur ON contributions(utilisateur_id);
CREATE INDEX idx_suggestions_liste ON suggestions(liste_id);
CREATE INDEX idx_notifications_utilisateur ON notifications(utilisateur_id);
CREATE INDEX idx_notifications_non_lues ON notifications(utilisateur_id, est_lue) WHERE est_lue = FALSE;

-- ============================================================================
-- DATA SAMPLE
-- ============================================================================

-- Insert sample users
INSERT INTO utilisateurs (id, nom, email, mot_de_passe_hash, photo_profil_url, est_administrateur) VALUES
('11111111-1111-1111-1111-111111111111', 'Hariss Houssam', 'hariss.houssam@example.com', '$2a$10$abcdefghijklmnopqrstuvwxyz123456', 'https://example.com/photos/hariss.jpg', TRUE),
('22222222-2222-2222-2222-222222222222', 'Es-serrar Achraf', 'achraf.esserrar@example.com', '$2a$10$abcdefghijklmnopqrstuvwxyz123456', 'https://example.com/photos/achraf.jpg', FALSE),
('33333333-3333-3333-3333-333333333333', 'Essamit Taha', 'taha.essamit@example.com', '$2a$10$abcdefghijklmnopqrstuvwxyz123456', 'https://example.com/photos/taha.jpg', FALSE),
('44444444-4444-4444-4444-444444444444', 'El Hauari Amine', 'amine.elhauari@example.com', '$2a$10$abcdefghijklmnopqrstuvwxyz123456', 'https://example.com/photos/amine.jpg', FALSE),
('55555555-5555-5555-5555-555555555555', 'Sophie Martin', 'sophie.martin@example.com', '$2a$10$abcdefghijklmnopqrstuvwxyz123456', NULL, FALSE),
('66666666-6666-6666-6666-666666666666', 'Lucas Dubois', 'lucas.dubois@example.com', '$2a$10$abcdefghijklmnopqrstuvwxyz123456', 'https://example.com/photos/lucas.jpg', FALSE);

-- Insert sample lists
INSERT INTO listes (id, titre, description, nom_evenement, date_evenement, photo_couverture_url, lien_partage, code_partage, visibilite_contributions, statut, proprietaire_id) VALUES
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Anniversaire de Sophie', 'Une liste pour l''anniversaire de Sophie, qui aime la technologie et les livres', 'Anniversaire Sophie 30 ans', '2026-06-15', 'https://example.com/covers/birthday1.jpg', 'giftplan.app/liste/aaaaaaaa', 'BIRTH2026', 'PUBLIC', 'ACTIVE', '22222222-2222-2222-2222-222222222222'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Mariage Amine & Lina', 'Liste de cadeaux pour notre mariage', 'Mariage', '2026-08-20', 'https://example.com/covers/wedding1.jpg', 'giftplan.app/liste/bbbbbbbb', 'WEDDING20', 'PRIVE', 'ACTIVE', '44444444-4444-4444-4444-444444444444'),
('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Crémaillère Taha', 'Pendaison de crémaillère dans le nouvel appartement', 'Crémaillère', '2026-05-10', NULL, 'giftplan.app/liste/cccccccc', 'HOUSE2026', 'ANONYME', 'ACTIVE', '33333333-3333-3333-3333-333333333333'),
('dddddddd-dddd-dddd-dddd-dddddddddddd', 'Fête Hariss 2025', 'Ancienne liste archivée', 'Anniversaire Hariss', '2025-12-20', NULL, 'giftplan.app/liste/dddddddd', 'HARISS25', 'PUBLIC', 'ARCHIVEE', '11111111-1111-1111-1111-111111111111');

-- Insert participations
INSERT INTO participations (liste_id, utilisateur_id, role) VALUES
-- Liste Sophie
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'PROPRIETAIRE'),
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333333', 'INVITE'),
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '44444444-4444-4444-4444-444444444444', 'INVITE'),
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '55555555-5555-5555-5555-555555555555', 'INVITE'),
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '66666666-6666-6666-6666-666666666666', 'EN_ATTENTE'),
-- Liste Mariage
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '44444444-4444-4444-4444-444444444444', 'PROPRIETAIRE'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', 'INVITE'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', 'INVITE'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '33333333-3333-3333-3333-333333333333', 'INVITE'),
-- Liste Crémaillère
('cccccccc-cccc-cccc-cccc-cccccccccccc', '33333333-3333-3333-3333-333333333333', 'PROPRIETAIRE'),
('cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', 'INVITE'),
('cccccccc-cccc-cccc-cccc-cccccccccccc', '55555555-5555-5555-5555-555555555555', 'INVITE'),
-- Liste archivée
('dddddddd-dddd-dddd-dddd-dddddddddddd', '11111111-1111-1111-1111-111111111111', 'PROPRIETAIRE');

-- Insert products
INSERT INTO produits (id, liste_id, nom, description, prix_cible, image_url, lien_url, categorie, statut_financement) VALUES
-- Produits pour l'anniversaire de Sophie
('p1111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'MacBook Air M3', 'Ordinateur portable Apple avec puce M3, 13 pouces, 256GB', 1299.99, 'https://example.com/products/macbook.jpg', 'https://apple.com/macbook-air', 'TECH', 'PARTIELLEMENT_FINANCE'),
('p2222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Kindle Paperwhite', 'Liseuse électronique avec éclairage intégré', 149.99, 'https://example.com/products/kindle.jpg', 'https://amazon.com/kindle', 'TECH', 'FINANCE'),
('p3333333-3333-3333-3333-333333333333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'AirPods Pro 2', 'Écouteurs sans fil avec réduction de bruit active', 279.99, 'https://example.com/products/airpods.jpg', 'https://apple.com/airpods-pro', 'TECH', 'NON_FINANCE'),
-- Produits pour le mariage
('p4444444-4444-4444-4444-444444444444', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Robot Cuiseur Thermomix', 'Robot de cuisine multifonction', 1399.00, 'https://example.com/products/thermomix.jpg', 'https://thermomix.com', 'MAISON', 'PARTIELLEMENT_FINANCE'),
('p5555555-5555-5555-5555-555555555555', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Service de table Villeroy & Boch', 'Service de table complet pour 12 personnes', 599.00, 'https://example.com/products/vaisselle.jpg', 'https://villeroy-boch.com', 'MAISON', 'NON_FINANCE'),
('p6666666-6666-6666-6666-666666666666', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Machine à café Nespresso', 'Machine à café avec mousseur de lait', 449.00, 'https://example.com/products/nespresso.jpg', 'https://nespresso.com', 'MAISON', 'FINANCE'),
-- Produits pour la crémaillère
('p7777777-7777-7777-7777-777777777777', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Canapé d''angle IKEA', 'Canapé d''angle 5 places en tissu gris', 899.00, 'https://example.com/products/canape.jpg', 'https://ikea.com/canape', 'MAISON', 'PARTIELLEMENT_FINANCE'),
('p8888888-8888-8888-8888-888888888888', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Lampe design', 'Lampadaire arc moderne', 189.00, 'https://example.com/products/lampe.jpg', NULL, 'MAISON', 'NON_FINANCE');

-- Insert contributions
INSERT INTO contributions (produit_id, utilisateur_id, montant, est_annulee) VALUES
-- Contributions pour MacBook Air
('p1111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 300.00, FALSE),
('p1111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444', 400.00, FALSE),
('p1111111-1111-1111-1111-111111111111', '55555555-5555-5555-5555-555555555555', 250.00, FALSE),
-- Contributions pour Kindle (entièrement financé)
('p2222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 75.00, FALSE),
('p2222222-2222-2222-2222-222222222222', '44444444-4444-4444-4444-444444444444', 74.99, FALSE),
-- Contributions pour Thermomix
('p4444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 500.00, FALSE),
('p4444444-4444-4444-4444-444444444444', '22222222-2222-2222-2222-222222222222', 400.00, FALSE),
-- Contributions pour Nespresso (entièrement financé)
('p6666666-6666-6666-6666-666666666666', '11111111-1111-1111-1111-111111111111', 200.00, FALSE),
('p6666666-6666-6666-6666-666666666666', '22222222-2222-2222-2222-222222222222', 249.00, FALSE),
-- Contributions pour Canapé
('p7777777-7777-7777-7777-777777777777', '11111111-1111-1111-1111-111111111111', 450.00, FALSE),
('p7777777-7777-7777-7777-777777777777', '55555555-5555-5555-5555-555555555555', 150.00, FALSE);

-- Insert suggestions
INSERT INTO suggestions (liste_id, utilisateur_id, nom_produit, description, prix_cible, lien_url, categorie, statut, date_suggestion) VALUES
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333333', 'Apple Watch Series 9', 'Montre connectée Apple dernière génération', 449.00, 'https://apple.com/watch', 'TECH', 'EN_ATTENTE', CURRENT_TIMESTAMP - INTERVAL '2 days'),
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '44444444-4444-4444-4444-444444444444', 'Sac à dos de voyage', 'Sac à dos pour ordinateur portable', 89.99, 'https://amazon.com/backpack', 'AUTRE', 'VALIDEE', CURRENT_TIMESTAMP - INTERVAL '5 days'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', 'Set de couteaux professionnel', 'Set de couteaux de cuisine haut de gamme', 299.00, NULL, 'MAISON', 'REFUSEE', CURRENT_TIMESTAMP - INTERVAL '3 days');

-- Insert notifications
INSERT INTO notifications (utilisateur_id, type, message, est_lue, date_envoi) VALUES
('22222222-2222-2222-2222-222222222222', 'CONTRIBUTION', 'Taha a contribué 300€ au MacBook Air', FALSE, CURRENT_TIMESTAMP - INTERVAL '1 hour'),
('22222222-2222-2222-2222-222222222222', 'FINANCEMENT', 'Le Kindle Paperwhite est entièrement financé !', TRUE, CURRENT_TIMESTAMP - INTERVAL '1 day'),
('22222222-2222-2222-2222-222222222222', 'SUGGESTION', 'Taha a suggéré un nouveau produit : Apple Watch Series 9', FALSE, CURRENT_TIMESTAMP - INTERVAL '2 days'),
('22222222-2222-2222-2222-222222222222', 'ADHESION', 'Lucas Dubois demande à rejoindre votre liste', FALSE, CURRENT_TIMESTAMP - INTERVAL '3 hours'),
('44444444-4444-4444-4444-444444444444', 'CONTRIBUTION', 'Hariss a contribué 500€ au Robot Cuiseur', TRUE, CURRENT_TIMESTAMP - INTERVAL '2 days'),
('44444444-4444-4444-4444-444444444444', 'FINANCEMENT', 'La Machine à café Nespresso est entièrement financée !', TRUE, CURRENT_TIMESTAMP - INTERVAL '1 day'),
('44444444-4444-4444-4444-444444444444', 'RAPPEL', 'Plus que 7 jours avant votre mariage !', FALSE, CURRENT_TIMESTAMP),
('33333333-3333-3333-3333-333333333333', 'CONTRIBUTION', 'Hariss a contribué 450€ au Canapé d''angle', FALSE, CURRENT_TIMESTAMP - INTERVAL '5 hours'),
('33333333-3333-3333-3333-333333333333', 'RAPPEL', 'Plus que 2 mois avant votre crémaillère', FALSE, CURRENT_TIMESTAMP - INTERVAL '1 day');

-- ============================================================================
-- END OF SCRIPT
-- ============================================================================

-- Verify data insertion
SELECT 'Users' as table_name, COUNT(*) as count FROM utilisateurs
UNION ALL
SELECT 'Listes', COUNT(*) FROM listes
UNION ALL
SELECT 'Participations', COUNT(*) FROM participations
UNION ALL
SELECT 'Produits', COUNT(*) FROM produits
UNION ALL
SELECT 'Contributions', COUNT(*) FROM contributions
UNION ALL
SELECT 'Suggestions', COUNT(*) FROM suggestions
UNION ALL
SELECT 'Notifications', COUNT(*) FROM notifications;