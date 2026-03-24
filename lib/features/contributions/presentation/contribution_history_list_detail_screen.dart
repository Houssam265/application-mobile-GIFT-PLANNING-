import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../profile/domain/profile_notifier.dart';
import '../domain/contribution_history_model.dart';
import '../domain/contribution_history_notifier.dart';
import 'contribution_history_widgets.dart';

/// Détail : contributions de l’utilisateur pour une liste, regroupées par produit.
class ContributionHistoryListDetailScreen extends ConsumerStatefulWidget {
  const ContributionHistoryListDetailScreen({super.key, required this.listId});

  final String listId;

  @override
  ConsumerState<ContributionHistoryListDetailScreen> createState() =>
      _ContributionHistoryListDetailScreenState();
}

class _ContributionHistoryListDetailScreenState
    extends ConsumerState<ContributionHistoryListDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(contributionHistoryDetailNotifierProvider(widget.listId).notifier)
          .load();
    });
  }

  /// Regroupe les lignes par [produitId], tri produits par date la plus récente.
  List<MapEntry<String, List<ContributionHistoryRow>>> _groupByProduct(
    List<ContributionHistoryRow> rows,
  ) {
    final map = <String, List<ContributionHistoryRow>>{};
    for (final r in rows) {
      map.putIfAbsent(r.contribution.produitId, () => []).add(r);
    }
    for (final list in map.values) {
      list.sort((a, b) => b.datePromesse.compareTo(a.datePromesse));
    }
    final entries = map.entries.toList();
    entries.sort((a, b) {
      final maxA = a.value.first.datePromesse;
      final maxB = b.value.first.datePromesse;
      return maxB.compareTo(maxA);
    });
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;
    final state =
        ref.watch(contributionHistoryDetailNotifierProvider(widget.listId));
    final profileName = ref.watch(profileNotifierProvider).displayName;

    final listTitle = state.items.isNotEmpty
        ? state.items.first.listTitre
        : 'Liste';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(listTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(contributionHistoryDetailNotifierProvider(widget.listId).notifier)
            .load(),
        child: _buildBody(context, theme, state, userId, profileName),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    ContributionHistoryDetailState state,
    String? userId,
    String? profileName,
  ) {
    if (state.status == ContributionHistoryStatus.loading &&
        state.items.isEmpty) {
      return const LoadingWidget(message: 'Chargement…');
    }

    if (state.status == ContributionHistoryStatus.error) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.padding),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.5,
            child: Center(
              child: Text(
                state.errorMessage ?? 'Erreur',
                style: theme.textTheme.bodyLarge?.copyWith(color: AppTheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    if (state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 48),
          EmptyState(
            title: 'Aucune contribution',
            message: 'Aucune contribution sur cette liste.',
            icon: Icons.volunteer_activism_outlined,
          ),
        ],
      );
    }

    final first = state.items.first;
    if (userId != null &&
        contributionHistoryIsPrivateParticipantView(first, userId)) {
      final total = state.items
          .where((e) => !e.contribution.estAnnulee)
          .fold<double>(0, (s, e) => s + e.contribution.montant);
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.padding),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  first.listTitre,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (first.isListArchived) const ContributionHistoryArchivedChip(),
            ],
          ),
          const SizedBox(height: 12),
          ContributionHistoryPrivateSummaryCard(totalMad: total),
        ],
      );
    }

    final grouped = _groupByProduct(state.items);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppTheme.padding),
      itemCount: grouped.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          final f = state.items.first;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    f.listTitre,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (f.isListArchived) const ContributionHistoryArchivedChip(),
              ],
            ),
          );
        }

        final entry = grouped[index - 1];
        final productRows = entry.value;
        final headerRow = productRows.first;

        return Padding(
          key: ValueKey<String>(entry.key),
          padding: const EdgeInsets.only(bottom: AppTheme.padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ContributionHistoryProductSectionHeader(
                productName: headerRow.productNom,
                prixCible: headerRow.prixCible,
              ),
              ...productRows.map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ContributionHistoryContributionCard(
                    row: row,
                    contributorName: contributionHistoryContributorDisplayName(
                      visibility: row.visibility,
                      profileName: profileName,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
