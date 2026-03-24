import '../../lists/data/list_repository.dart';
import 'contribution_model.dart';

/// Résumé d’une liste pour laquelle l’utilisateur a au moins une contribution.
class ContributionHistoryListSummary {
  const ContributionHistoryListSummary({
    required this.listeId,
    required this.titre,
    required this.visibility,
    required this.listStatut,
    required this.proprietaireId,
    required this.lastContributionAt,
    required this.contributionCount,
  });

  final String listeId;
  final String titre;
  final ListVisibility visibility;
  final String listStatut;
  final String proprietaireId;
  final DateTime lastContributionAt;
  final int contributionCount;

  bool get isListArchived => listStatut.toUpperCase() == 'ARCHIVEE';

  /// Regroupe les lignes d’historique par liste (une entrée par liste).
  static List<ContributionHistoryListSummary> aggregate(
    List<ContributionHistoryRow> rows,
  ) {
    final map = <String, List<ContributionHistoryRow>>{};
    for (final r in rows) {
      map.putIfAbsent(r.listeId, () => []).add(r);
    }
    final out = map.entries.map((e) {
      final list = e.value;
      final first = list.first;
      final last = list
          .map((x) => x.datePromesse)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      return ContributionHistoryListSummary(
        listeId: e.key,
        titre: first.listTitre,
        visibility: first.visibility,
        listStatut: first.listStatut,
        proprietaireId: first.proprietaireId,
        lastContributionAt: last,
        contributionCount: list.length,
      );
    }).toList();
    out.sort((a, b) => b.lastContributionAt.compareTo(a.lastContributionAt));
    return out;
  }
}

/// Ligne d’historique : contribution courante + métadonnées produit / liste (jointure).
class ContributionHistoryRow {
  const ContributionHistoryRow({
    required this.contribution,
    required this.productNom,
    required this.prixCible,
    required this.listeId,
    required this.listTitre,
    required this.visibility,
    required this.listStatut,
    required this.proprietaireId,
  });

  final ContributionModel contribution;
  final String productNom;
  final double prixCible;
  final String listeId;
  final String listTitre;
  final ListVisibility visibility;
  final String listStatut;
  final String proprietaireId;

  DateTime get datePromesse => contribution.datePromesse;

  bool get isListArchived =>
      listStatut.toUpperCase() == 'ARCHIVEE';

  factory ContributionHistoryRow.fromSupabaseMap(Map<String, dynamic> map) {
    final produitsRaw = map['produits'];
    if (produitsRaw is! Map<String, dynamic>) {
      throw FormatException('contributions.produits manquant ou invalide');
    }
    final listesRaw = produitsRaw['listes'];
    if (listesRaw is! Map<String, dynamic>) {
      throw FormatException('produits.listes manquant ou invalide');
    }

    final visRaw =
        (listesRaw['visibilite_contributions'] as String?) ?? 'PUBLIC';

    final prixRaw = produitsRaw['prix_cible'];
    final prixCible = prixRaw is num
        ? prixRaw.toDouble()
        : double.tryParse(prixRaw?.toString() ?? '') ?? 0.0;

    return ContributionHistoryRow(
      contribution: ContributionModel.fromMap(map),
      productNom: (produitsRaw['nom'] as String?) ?? 'Produit',
      prixCible: prixCible,
      listeId: (produitsRaw['liste_id'] as String?) ?? '',
      listTitre: (listesRaw['titre'] as String?) ?? 'Liste',
      visibility: visibilityFromDb(visRaw),
      listStatut: (listesRaw['statut'] as String?) ?? 'ACTIVE',
      proprietaireId: (listesRaw['proprietaire_id'] as String?) ?? '',
    );
  }
}
