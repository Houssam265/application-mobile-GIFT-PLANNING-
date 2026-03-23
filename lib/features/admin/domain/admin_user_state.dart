import '../domain/admin_user_model.dart';
import '../../profile/domain/profile_state.dart'; // Just to re-use ProfileStatus, or I can define a local enum

enum AdminUserStatus { initial, loading, success, error }

class AdminUserState {
  final AdminUserStatus status;
  final List<AdminUserModel> users;
  final String? errorMessage;
  final String searchQuery;

  const AdminUserState({
    this.status = AdminUserStatus.initial,
    this.users = const [],
    this.errorMessage,
    this.searchQuery = '',
  });

  AdminUserState copyWith({
    AdminUserStatus? status,
    List<AdminUserModel>? users,
    String? errorMessage,
    String? searchQuery,
  }) {
    return AdminUserState(
      status: status ?? this.status,
      users: users ?? this.users,
      errorMessage: errorMessage ?? this.errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}
