import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_widget.dart';
import '../domain/contribution_history_notifier.dart';

/// GP-29 — Choix d’une liste pour consulter l’historique des contributions.
class ContributionHistoryScreen extends ConsumerStatefulWidget {
  const ContributionHistoryScreen({super.key});

  @override
  ConsumerState<ContributionHistoryScreen> createState() =>
      _ContributionHistoryScreenState();
}

class _ContributionHistoryScreenState
    extends ConsumerState<ContributionHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contributionHistoryListsNotifierProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(contributionHistoryListsNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Historique des contributions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(contributionHistoryListsNotifierProvider.notifier).load(),
        child: _buildBody(context, theme, state),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    ContributionHistoryListsState state,
  ) {
    if (state.status == ContributionHistoryStatus.loading &&
        state.lists.isEmpty) {
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

    if (state.lists.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 48),
          EmptyState(
            title: 'Aucune contribution',
            message:
                'Vous n’avez encore promis de contribution sur aucune liste.',
            icon: Icons.volunteer_activism_outlined,
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppTheme.padding),
      itemCount: state.lists.length,
      itemBuilder: (context, index) {
        final s = state.lists[index];
        return Padding(
          key: ValueKey<String>(s.listeId),
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            onTap: () => context.pushNamed(
              AppRouteName.contributionsHistoryList,
              pathParameters: {'listId': s.listeId},
            ),
            child: Row(
              children: [
                Icon(Icons.list_alt, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.titre,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (s.isListArchived)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Chip(
                                label: const Text('Archivée'),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${s.contributionCount} contribution${s.contributionCount > 1 ? 's' : ''} · '
                        'dernière : ${_formatShortDate(s.lastContributionAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppTheme.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatShortDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
