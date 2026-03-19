class ContributionModel {
  const ContributionModel({
    required this.id,
    required this.produitId,
    required this.utilisateurId,
    required this.montant,
    this.estAnnulee = false,
    required this.datePromesse,
    this.dateModification,
  });

  final String id;
  final String produitId;
  final String utilisateurId;
  final double montant;
  final bool estAnnulee;
  final DateTime datePromesse;
  final DateTime? dateModification;

  factory ContributionModel.fromMap(Map<String, dynamic> map) {
    final montantRaw = map['montant'];
    final montant = montantRaw is num
        ? montantRaw.toDouble()
        : double.tryParse(montantRaw?.toString() ?? '') ?? 0.0;

    final datePromesseRaw = map['date_promesse'];
    final datePromesse = datePromesseRaw is String
        ? DateTime.parse(datePromesseRaw)
        : (datePromesseRaw as DateTime);

    final dateModificationRaw = map['date_modification'];
    final dateModification = dateModificationRaw == null
        ? null
        : (dateModificationRaw is String
            ? DateTime.parse(dateModificationRaw)
            : dateModificationRaw as DateTime);

    return ContributionModel(
      id: map['id'] as String,
      produitId: map['produit_id'] as String,
      utilisateurId: map['utilisateur_id'] as String,
      montant: montant,
      estAnnulee: (map['est_annulee'] as bool?) ?? false,
      datePromesse: datePromesse,
      dateModification: dateModification,
    );
  }
}

