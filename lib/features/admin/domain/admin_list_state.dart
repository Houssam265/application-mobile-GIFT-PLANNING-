import '../domain/admin_list_model.dart';
import '../../profile/domain/profile_state.dart'; // Pour Status

enum AdminListStatus { initial, loading, success, error }

class AdminListState {
  final AdminListStatus status;
  final List<AdminListModel> lists;
  final String? errorMessage;
  final String searchQuery;
  final String currentFilter; // 'TOUTES', 'ACTIVE', 'ARCHIVEE'

  const AdminListState({
    this.status = AdminListStatus.initial,
    this.lists = const [],
    this.errorMessage,
    this.searchQuery = '',
    this.currentFilter = 'TOUTES',
  });

  AdminListState copyWith({
    AdminListStatus? status,
    List<AdminListModel>? lists,
    String? errorMessage,
    String? searchQuery,
    String? currentFilter,
  }) {
    return AdminListState(
      status: status ?? this.status,
      lists: lists ?? this.lists,
      errorMessage: errorMessage ?? this.errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      currentFilter: currentFilter ?? this.currentFilter,
    );
  }
}
