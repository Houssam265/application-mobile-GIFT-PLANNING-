import '../domain/admin_log_model.dart';

enum AdminLogStatus { initial, loading, success, error }

class AdminLogState {
  final List<AdminLog> logs;
  final AdminLogStatus status;
  final String? errorMessage;
  final bool hasReachedMax;
  final String? actionFilter;
  final DateTime? startDate;
  final DateTime? endDate;

  AdminLogState({
    this.logs = const [],
    this.status = AdminLogStatus.initial,
    this.errorMessage,
    this.hasReachedMax = false,
    this.actionFilter,
    this.startDate,
    this.endDate,
  });

  AdminLogState copyWith({
    List<AdminLog>? logs,
    AdminLogStatus? status,
    String? errorMessage,
    bool? hasReachedMax,
    String? actionFilter,
    DateTime? startDate,
    DateTime? endDate,
    bool clearActionFilter = false,
    bool clearDateRange = false,
  }) {
    return AdminLogState(
      logs: logs ?? this.logs,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      actionFilter: clearActionFilter ? null : (actionFilter ?? this.actionFilter),
      startDate: clearDateRange ? null : (startDate ?? this.startDate),
      endDate: clearDateRange ? null : (endDate ?? this.endDate),
    );
  }
}
