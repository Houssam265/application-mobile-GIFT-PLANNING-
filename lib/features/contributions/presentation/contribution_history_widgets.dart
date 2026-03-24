import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../lists/data/list_repository.dart';
import '../domain/contribution_history_model.dart';

String contributionHistoryFormatDate(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final yyyy = d.year.toString();
  return '$dd/$mm/$yyyy';
}

String contributionHistoryContributorDisplayName({
  required ListVisibility visibility,
  required String? profileName,
}) {
  switch (visibility) {
    case ListVisibility.anonymous:
      return 'Un participant';
    case ListVisibility.public:
    case ListVisibility.private:
      if (profileName != null && profileName.trim().isNotEmpty) {
        return profileName.trim();
      }
      return 'Vous';
  }
}

bool contributionHistoryIsPrivateParticipantView(
  ContributionHistoryRow row,
  String userId,
) {
  return row.visibility == ListVisibility.private &&
      row.proprietaireId != userId;
}

class ContributionHistoryArchivedChip extends StatelessWidget {
  const ContributionHistoryArchivedChip({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      label: const Text('Archivée'),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
    );
  }
}

class ContributionHistoryPrivateSummaryCard extends StatelessWidget {
  const ContributionHistoryPrivateSummaryCard({super.key, required this.totalMad});

  final double totalMad;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Contribution : ${totalMad.toStringAsFixed(2)} MAD',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ContributionHistoryContributionCard extends StatelessWidget {
  const ContributionHistoryContributionCard({
    super.key,
    required this.row,
    required this.contributorName,
  });

  final ContributionHistoryRow row;
  final String contributorName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = row.contribution;
    final cancelled = c.estAnnulee;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${c.montant.toStringAsFixed(2)} MAD',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Date : ${contributionHistoryFormatDate(c.datePromesse)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ContributionHistoryStatusChip(cancelled: cancelled),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Contributeur : $contributorName',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class ContributionHistoryStatusChip extends StatelessWidget {
  const ContributionHistoryStatusChip({super.key, required this.cancelled});

  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (cancelled) {
      return Chip(
        label: const Text('Annulée'),
        backgroundColor: theme.colorScheme.errorContainer,
        labelStyle: TextStyle(
          color: theme.colorScheme.onErrorContainer,
          fontSize: 12,
        ),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }
    return Chip(
      label: const Text('Active'),
      backgroundColor: theme.colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: theme.colorScheme.onPrimaryContainer,
        fontSize: 12,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// En-tête de section produit (nom + prix cible).
class ContributionHistoryProductSectionHeader extends StatelessWidget {
  const ContributionHistoryProductSectionHeader({
    super.key,
    required this.productName,
    required this.prixCible,
  });

  final String productName;
  final double prixCible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            productName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Prix cible : ${prixCible.toStringAsFixed(2)} MAD',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
