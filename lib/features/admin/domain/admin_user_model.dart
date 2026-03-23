class AdminUserModel {
  final String id;
  final String nom;
  final String email;
  final String? photoProfilUrl;
  final bool estSuspendu;
  final bool estAdministrateur;
  final DateTime? dateInscription;

  AdminUserModel({
    required this.id,
    required this.nom,
    required this.email,
    this.photoProfilUrl,
    required this.estSuspendu,
    required this.estAdministrateur,
    this.dateInscription,
  });

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    return AdminUserModel(
      id: json['id'] as String,
      nom: json['nom'] as String,
      email: json['email'] as String,
      photoProfilUrl: json['photo_profil_url'] as String?,
      estSuspendu: json['est_suspendu'] as bool? ?? false,
      estAdministrateur: json['est_administrateur'] as bool? ?? false,
      dateInscription: json['date_inscription'] != null
          ? DateTime.tryParse(json['date_inscription'] as String)
          : null,
    );
  }

  AdminUserModel copyWith({
    String? id,
    String? nom,
    String? email,
    String? photoProfilUrl,
    bool? estSuspendu,
    bool? estAdministrateur,
    DateTime? dateInscription,
  }) {
    return AdminUserModel(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      email: email ?? this.email,
      photoProfilUrl: photoProfilUrl ?? this.photoProfilUrl,
      estSuspendu: estSuspendu ?? this.estSuspendu,
      estAdministrateur: estAdministrateur ?? this.estAdministrateur,
      dateInscription: dateInscription ?? this.dateInscription,
    );
  }
}
