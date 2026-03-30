class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.utilisateurId,
    required this.type,
    required this.message,
    required this.estLue,
    required this.dateEnvoi,
    this.action,
    this.listeId,
    this.produitId,
    this.suggestionId,
  });

  final String id;
  final String utilisateurId;
  final String type;
  final String message;
  final bool estLue;
  final DateTime dateEnvoi;
  final String? action;
  final String? listeId;
  final String? produitId;
  final String? suggestionId;

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    final rawDate = map['date_envoi'];
    DateTime dateEnvoi;
    if (rawDate is String) {
      dateEnvoi = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      dateEnvoi = DateTime.now();
    }
    return NotificationModel(
      id: map['id'] as String,
      utilisateurId: map['utilisateur_id'] as String,
      type: (map['type'] as String?) ?? 'RAPPEL',
      message: (map['message'] as String?) ?? '',
      estLue: map['est_lue'] as bool? ?? false,
      dateEnvoi: dateEnvoi,
      action: map['action'] as String?,
      listeId: map['liste_id'] as String?,
      produitId: map['produit_id'] as String?,
      suggestionId: map['suggestion_id'] as String?,
    );
  }

  NotificationModel copyWith({
    bool? estLue,
  }) {
    return NotificationModel(
      id: id,
      utilisateurId: utilisateurId,
      type: type,
      message: message,
      estLue: estLue ?? this.estLue,
      dateEnvoi: dateEnvoi,
      action: action,
      listeId: listeId,
      produitId: produitId,
      suggestionId: suggestionId,
    );
  }
}
