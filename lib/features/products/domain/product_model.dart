enum ProductCategorie {
  tech,
  mode,
  maison,
  sport,
  autre,
}

extension ProductCategorieExtension on ProductCategorie {
  String get dbValue {
    switch (this) {
      case ProductCategorie.tech:
        return 'TECH';
      case ProductCategorie.mode:
        return 'MODE';
      case ProductCategorie.maison:
        return 'MAISON';
      case ProductCategorie.sport:
        return 'SPORT';
      case ProductCategorie.autre:
        return 'AUTRE';
    }
  }

  String get label {
    switch (this) {
      case ProductCategorie.tech:
        return 'Tech';
      case ProductCategorie.mode:
        return 'Mode';
      case ProductCategorie.maison:
        return 'Maison';
      case ProductCategorie.sport:
        return 'Sport';
      case ProductCategorie.autre:
        return 'Autre';
    }
  }
}

ProductCategorie productCategorieFromDb(String value) {
  switch (value.toUpperCase()) {
    case 'TECH':
      return ProductCategorie.tech;
    case 'MODE':
      return ProductCategorie.mode;
    case 'MAISON':
      return ProductCategorie.maison;
    case 'SPORT':
      return ProductCategorie.sport;
    default:
      return ProductCategorie.autre;
  }
}

enum StatutFinancement {
  nonFinance,
  partiellementFinance,
  finance,
}

extension StatutFinancementExtension on StatutFinancement {
  String get dbValue {
    switch (this) {
      case StatutFinancement.nonFinance:
        return 'NON_FINANCE';
      case StatutFinancement.partiellementFinance:
        return 'PARTIELLEMENT_FINANCE';
      case StatutFinancement.finance:
        return 'FINANCE';
    }
  }
}

StatutFinancement statutFinancementFromDb(String value) {
  switch (value.toUpperCase()) {
    case 'FINANCE':
      return StatutFinancement.finance;
    case 'PARTIELLEMENT_FINANCE':
      return StatutFinancement.partiellementFinance;
    default:
      return StatutFinancement.nonFinance;
  }
}

class ProductModel {
  const ProductModel({
    required this.id,
    required this.listeId,
    required this.nom,
    this.description,
    required this.prixCible,
    this.imageUrl,
    this.lienUrl,
    this.categorie,
    required this.statutFinancement,
    required this.dateCreation,
    required this.dateModification,
  });

  final String id;
  final String listeId;
  final String nom;
  final String? description;
  final double prixCible;
  final String? imageUrl;
  final String? lienUrl;
  final ProductCategorie? categorie;
  final StatutFinancement statutFinancement;
  final DateTime dateCreation;
  final DateTime dateModification;

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as String,
      listeId: map['liste_id'] as String,
      nom: map['nom'] as String,
      description: map['description'] as String?,
      prixCible: (map['prix_cible'] as num).toDouble(),
      imageUrl: map['image_url'] as String?,
      lienUrl: map['lien_url'] as String?,
      categorie: map['categorie'] != null
          ? productCategorieFromDb(map['categorie'] as String)
          : null,
      statutFinancement: statutFinancementFromDb(
        map['statut_financement'] as String? ?? 'NON_FINANCE',
      ),
      dateCreation: DateTime.parse(map['date_creation'] as String),
      dateModification: DateTime.parse(map['date_modification'] as String),
    );
  }
}
