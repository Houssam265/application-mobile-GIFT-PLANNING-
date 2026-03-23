class AdminListModel {
  final String id;
  final String titre;
  final String? description;
  final String nomEvenement;
  final DateTime dateEvenement;
  final String statut;
  final String proprietaireId;
  final String proprietaireNom;
  final String proprietaireEmail;
  final DateTime dateCreation;
  final DateTime? dateArchivage;

  AdminListModel({
    required this.id,
    required this.titre,
    this.description,
    required this.nomEvenement,
    required this.dateEvenement,
    required this.statut,
    required this.proprietaireId,
    required this.proprietaireNom,
    required this.proprietaireEmail,
    required this.dateCreation,
    this.dateArchivage,
  });

  factory AdminListModel.fromJson(Map<String, dynamic> json) {
    // Gestion de la jointure vers utilisateurs
    final utilisateurData = json['utilisateurs'] as Map<String, dynamic>? ?? {};

    return AdminListModel(
      id: json['id'] as String,
      titre: json['titre'] as String,
      description: json['description'] as String?,
      nomEvenement: json['nom_evenement'] as String,
      dateEvenement: DateTime.parse(json['date_evenement'] as String),
      statut: json['statut'] as String,
      proprietaireId: json['proprietaire_id'] as String,
      proprietaireNom: utilisateurData['nom'] as String? ?? 'Utilisateur inconnu',
      proprietaireEmail: utilisateurData['email'] as String? ?? 'Sans email',
      dateCreation: DateTime.parse(json['date_creation'] as String),
      dateArchivage: json['date_archivage'] != null
          ? DateTime.tryParse(json['date_archivage'] as String)
          : null,
    );
  }

  AdminListModel copyWith({
    String? id,
    String? titre,
    String? description,
    String? nomEvenement,
    DateTime? dateEvenement,
    String? statut,
    String? proprietaireId,
    String? proprietaireNom,
    String? proprietaireEmail,
    DateTime? dateCreation,
    DateTime? dateArchivage,
  }) {
    return AdminListModel(
      id: id ?? this.id,
      titre: titre ?? this.titre,
      description: description ?? this.description,
      nomEvenement: nomEvenement ?? this.nomEvenement,
      dateEvenement: dateEvenement ?? this.dateEvenement,
      statut: statut ?? this.statut,
      proprietaireId: proprietaireId ?? this.proprietaireId,
      proprietaireNom: proprietaireNom ?? this.proprietaireNom,
      proprietaireEmail: proprietaireEmail ?? this.proprietaireEmail,
      dateCreation: dateCreation ?? this.dateCreation,
      dateArchivage: dateArchivage ?? this.dateArchivage,
    );
  }
}
