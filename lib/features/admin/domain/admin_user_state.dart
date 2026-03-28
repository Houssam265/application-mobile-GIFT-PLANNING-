import '../domain/admin_user_model.dart';

enum AdminUserStatus { initial, loading, success, error }

class AdminUserState {
  final AdminUserStatus status;
  final List<AdminUserModel> users;
  final String? errorMessage;
  final String searchQuery;
  final String currentFilter; // 'TOUT', 'ACTIFS', 'SUSPENDUS'
  final int totalUsers;
  final int activeUsers;
  final int suspendedUsers;
  /// Set to true ONLY after a user-initiated mutation (suspend/reactivate).
  /// Regular fetches must never set this to true.
  final bool actionSucceeded;

  const AdminUserState({
    this.status = AdminUserStatus.initial,
    this.users = const [],
    this.errorMessage,
    this.searchQuery = '',
    this.currentFilter = 'TOUT',
    this.totalUsers = 0,
    this.activeUsers = 0,
    this.suspendedUsers = 0,
    this.actionSucceeded = false,
  });

  AdminUserState copyWith({
    AdminUserStatus? status,
    List<AdminUserModel>? users,
    String? errorMessage,
    String? searchQuery,
    String? currentFilter,
    int? totalUsers,
    int? activeUsers,
    int? suspendedUsers,
    bool? actionSucceeded,
  }) {
    return AdminUserState(
      status: status ?? this.status,
      users: users ?? this.users,
      errorMessage: errorMessage ?? this.errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      currentFilter: currentFilter ?? this.currentFilter,
      totalUsers: totalUsers ?? this.totalUsers,
      activeUsers: activeUsers ?? this.activeUsers,
      suspendedUsers: suspendedUsers ?? this.suspendedUsers,
      actionSucceeded: actionSucceeded ?? this.actionSucceeded,
    );
  }
}
