import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/contribution_repository.dart';
import 'contribution_model.dart';

// ── Repository provider ───────────────────────────────────────────────────────
final contributionRepositoryProvider = Provider<ContributionRepository>(
  (_) => ContributionRepository(),
);

enum ContributionFormStatus { idle, loading, success, error }

class ContributionFormState {
  const ContributionFormState({
    this.status = ContributionFormStatus.idle,
    this.errorMessage,
  });

  final ContributionFormStatus status;
  final String? errorMessage;

  ContributionFormState copyWith({
    ContributionFormStatus? status,
    String? errorMessage,
  }) {
    return ContributionFormState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class ContributionFormNotifier extends StateNotifier<ContributionFormState> {
  ContributionFormNotifier(this._repository) : super(const ContributionFormState());

  final ContributionRepository _repository;

  Future<void> submitContribution({
    required String listId,
    required String productId,
    required String userId,
    required double amount,
    ContributionModel? existingContribution,
  }) async {
    state = state.copyWith(status: ContributionFormStatus.loading, errorMessage: null);
    try {
      // Enforce rules server-side:
      // - If user already contributed: update the single contribution row.
      // - Otherwise insert a new pledge.
      if (existingContribution != null) {
        await _repository.updateContribution(existingContribution.id, amount);
      } else {
        await _repository.addContribution(
          listId: listId,
          productId: productId,
          userId: userId,
          amount: amount,
        );
      }

      state = state.copyWith(status: ContributionFormStatus.success);
    } catch (e) {
      state = state.copyWith(
        status: ContributionFormStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() => state = const ContributionFormState();
}

// ── Providers ──────────────────────────────────────────────────────────────────
final contributionFormProvider = StateNotifierProvider.autoDispose<
    ContributionFormNotifier, ContributionFormState>(
  (ref) => ContributionFormNotifier(ref.watch(contributionRepositoryProvider)),
);

