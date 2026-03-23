import '../../products/domain/product_model.dart';

enum SuggestionStatus {
  enAttente,
  validee,
  refusee,
}

extension SuggestionStatusExtension on SuggestionStatus {
  String get dbValue {
    switch (this) {
      case SuggestionStatus.enAttente:
        return 'EN_ATTENTE';
      case SuggestionStatus.validee:
        return 'VALIDEE';
      case SuggestionStatus.refusee:
        return 'REFUSEE';
    }
  }
}

SuggestionStatus suggestionStatusFromDb(String value) {
  switch (value.toUpperCase()) {
    case 'VALIDEE':
      return SuggestionStatus.validee;
    case 'REFUSEE':
      return SuggestionStatus.refusee;
    default:
      return SuggestionStatus.enAttente;
  }
}

class SuggestionModel {
  const SuggestionModel({
    required this.id,
    required this.listeId,
    required this.utilisateurId,
    required this.nomProduit,
    this.description,
    required this.prixCible,
    this.imageUrl,
    this.lienUrl,
    this.categorie,
    required this.statut,
    this.motifRefus,
    required this.dateSuggestion,
    this.dateTraitement,
  });

  final String id;
  final String listeId;
  final String utilisateurId;
  final String nomProduit;
  final String? description;
  final double prixCible;
  final String? imageUrl;
  final String? lienUrl;
  final ProductCategorie? categorie;
  final SuggestionStatus statut;
  final String? motifRefus;
  final DateTime dateSuggestion;
  final DateTime? dateTraitement;

  factory SuggestionModel.fromJson(Map<String, dynamic> json) {
    return SuggestionModel(
      id: json['id'] as String,
      listeId: json['liste_id'] as String,
      utilisateurId: json['utilisateur_id'] as String,
      nomProduit: json['nom_produit'] as String,
      description: json['description'] as String?,
      prixCible: (json['prix_cible'] as num).toDouble(),
      imageUrl: json['image_url'] as String?,
      lienUrl: json['lien_url'] as String?,
      categorie: json['categorie'] != null
          ? productCategorieFromDb(json['categorie'] as String)
          : null,
      statut: suggestionStatusFromDb(
        json['statut'] as String? ?? SuggestionStatus.enAttente.dbValue,
      ),
      motifRefus: json['motif_refus'] as String?,
      dateSuggestion: DateTime.parse(json['date_suggestion'] as String),
      dateTraitement: json['date_traitement'] != null
          ? DateTime.parse(json['date_traitement'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'liste_id': listeId,
      'utilisateur_id': utilisateurId,
      'nom_produit': nomProduit,
      'description': description,
      'prix_cible': prixCible,
      'image_url': imageUrl,
      'lien_url': lienUrl,
      'categorie': categorie?.dbValue,
      'statut': statut.dbValue,
      'motif_refus': motifRefus,
      'date_suggestion': dateSuggestion.toIso8601String(),
      'date_traitement': dateTraitement?.toIso8601String(),
    };
  }
}
