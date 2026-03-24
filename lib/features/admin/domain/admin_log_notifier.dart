import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_log_repository.dart';
import '../domain/admin_log_state.dart';

final adminLogNotifierProvider = StateNotifierProvider<AdminLogNotifier, AdminLogState>((ref) {
  final repository = AdminLogRepository();
  return AdminLogNotifier(repository);
});

class AdminLogNotifier extends StateNotifier<AdminLogState> {
  final AdminLogRepository _repository;
  static const int _limit = 20;

  AdminLogNotifier(this._repository) : super(AdminLogState()) {
    fetchLogs();
  }

  Future<void> fetchLogs({bool reset = false}) async {
    if (state.status == AdminLogStatus.loading) return;

    if (reset) {
      state = state.copyWith(logs: [], status: AdminLogStatus.loading, hasReachedMax: false);
    } else if (state.hasReachedMax) {
      return;
    } else {
      state = state.copyWith(status: AdminLogStatus.loading);
    }

    try {
      final newLogs = await _repository.fetchLogs(
        limit: _limit,
        offset: state.logs.length,
        actionFilter: state.actionFilter,
        startDate: state.startDate,
        endDate: state.endDate,
      );

      state = state.copyWith(
        status: AdminLogStatus.success,
        logs: [...state.logs, ...newLogs],
        hasReachedMax: newLogs.length < _limit,
      );
    } catch (e) {
      state = state.copyWith(
        status: AdminLogStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void onActionFilterChanged(String? action) {
    if (state.actionFilter == action) return;
    state = state.copyWith(actionFilter: action, clearActionFilter: action == null);
    fetchLogs(reset: true);
  }

  void onDateRangeChanged(DateTime? start, DateTime? end) {
    state = state.copyWith(
      startDate: start,
      endDate: end,
      clearDateRange: start == null && end == null,
    );
    fetchLogs(reset: true);
  }

  void resetFilters() {
    state = state.copyWith(
      clearActionFilter: true,
      clearDateRange: true,
    );
    fetchLogs(reset: true);
  }
}
