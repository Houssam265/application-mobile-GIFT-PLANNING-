import '../domain/admin_list_model.dart';

enum AdminListStatus { initial, loading, success, error }

class AdminListState {
  final AdminListStatus status;
  final List<AdminListModel> lists;
  final String? errorMessage;
  final String searchQuery;
  final String currentFilter; // 'TOUTES', 'ACTIVE', 'ARCHIVEE'
  final int totalLists;
  final int activeLists;
  final int archivedLists;
  final bool actionSucceeded;

  const AdminListState({
    this.status = AdminListStatus.initial,
    this.lists = const [],
    this.errorMessage,
    this.searchQuery = '',
    this.currentFilter = 'TOUTES',
    this.totalLists = 0,
    this.activeLists = 0,
    this.archivedLists = 0,
    this.actionSucceeded = false,
  });

  AdminListState copyWith({
    AdminListStatus? status,
    List<AdminListModel>? lists,
    String? errorMessage,
    String? searchQuery,
    String? currentFilter,
    int? totalLists,
    int? activeLists,
    int? archivedLists,
    bool? actionSucceeded,
  }) {
    return AdminListState(
      status: status ?? this.status,
      lists: lists ?? this.lists,
      errorMessage: errorMessage ?? this.errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      currentFilter: currentFilter ?? this.currentFilter,
      totalLists: totalLists ?? this.totalLists,
      activeLists: activeLists ?? this.activeLists,
      archivedLists: archivedLists ?? this.archivedLists,
      actionSucceeded: actionSucceeded ?? this.actionSucceeded,
    );
  }
}
