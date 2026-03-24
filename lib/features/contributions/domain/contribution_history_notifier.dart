import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/contribution_repository.dart';
import 'contribution_history_model.dart';
import 'contribution_notifier.dart';

enum ContributionHistoryStatus { initial, loading, success, error }

// ── Écran liste (choix de la liste) ───────────────────────────────────────────

class ContributionHistoryListsState {
  const ContributionHistoryListsState({
    this.status = ContributionHistoryStatus.initial,
    this.errorMessage,
    this.lists = const [],
  });

  final ContributionHistoryStatus status;
  final String? errorMessage;
  final List<ContributionHistoryListSummary> lists;

  ContributionHistoryListsState copyWith({
    ContributionHistoryStatus? status,
    String? errorMessage,
    List<ContributionHistoryListSummary>? lists,
    bool clearError = false,
  }) {
    return ContributionHistoryListsState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lists: lists ?? this.lists,
    );
  }
}

final contributionHistoryListsNotifierProvider = StateNotifierProvider.autoDispose<
    ContributionHistoryListsNotifier, ContributionHistoryListsState>(
  (ref) => ContributionHistoryListsNotifier(
    ref.watch(contributionRepositoryProvider),
  ),
);

class ContributionHistoryListsNotifier
    extends StateNotifier<ContributionHistoryListsState> {
  ContributionHistoryListsNotifier(this._repository)
      : super(const ContributionHistoryListsState());

  final ContributionRepository _repository;

  Future<void> load() async {
    state = state.copyWith(
      status: ContributionHistoryStatus.loading,
      clearError: true,
    );
    try {
      final lists = await _repository.fetchContributionHistoryListSummaries();
      state = ContributionHistoryListsState(
        status: ContributionHistoryStatus.success,
        lists: lists,
      );
    } catch (e) {
      state = ContributionHistoryListsState(
        status: ContributionHistoryStatus.error,
        errorMessage: e.toString(),
        lists: const [],
      );
    }
  }
}

// ── Écran détail (contributions par produit pour une liste) ─────────────────

class ContributionHistoryDetailState {
  const ContributionHistoryDetailState({
    this.status = ContributionHistoryStatus.initial,
    this.errorMessage,
    this.items = const [],
  });

  final ContributionHistoryStatus status;
  final String? errorMessage;
  final List<ContributionHistoryRow> items;

  ContributionHistoryDetailState copyWith({
    ContributionHistoryStatus? status,
    String? errorMessage,
    List<ContributionHistoryRow>? items,
    bool clearError = false,
  }) {
    return ContributionHistoryDetailState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      items: items ?? this.items,
    );
  }
}

final contributionHistoryDetailNotifierProvider = StateNotifierProvider
    .autoDispose.family<ContributionHistoryDetailNotifier,
        ContributionHistoryDetailState, String>(
  (ref, listId) => ContributionHistoryDetailNotifier(
    ref.watch(contributionRepositoryProvider),
    listId,
  ),
);

class ContributionHistoryDetailNotifier
    extends StateNotifier<ContributionHistoryDetailState> {
  ContributionHistoryDetailNotifier(this._repository, this._listId)
      : super(const ContributionHistoryDetailState());

  final ContributionRepository _repository;
  final String _listId;

  Future<void> load() async {
    state = state.copyWith(
      status: ContributionHistoryStatus.loading,
      clearError: true,
    );
    try {
      final items = await _repository.fetchContributionHistoryForList(_listId);
      state = ContributionHistoryDetailState(
        status: ContributionHistoryStatus.success,
        items: items,
      );
    } catch (e) {
      state = ContributionHistoryDetailState(
        status: ContributionHistoryStatus.error,
        errorMessage: e.toString(),
        items: const [],
      );
    }
  }
}
