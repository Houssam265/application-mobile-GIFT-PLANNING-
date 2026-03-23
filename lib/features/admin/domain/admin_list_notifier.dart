import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_list_repository.dart';
import 'admin_list_state.dart';

final adminListRepositoryProvider = Provider<AdminListRepository>((ref) {
  return AdminListRepository();
});

final adminListNotifierProvider =
    StateNotifierProvider<AdminListNotifier, AdminListState>((ref) {
  return AdminListNotifier(ref.read(adminListRepositoryProvider));
});

class AdminListNotifier extends StateNotifier<AdminListState> {
  final AdminListRepository _repository;
  Timer? _debounceTimer;

  AdminListNotifier(this._repository) : super(const AdminListState()) {
    fetchLists();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void onSearchQueryChanged(String query) {
    state = state.copyWith(searchQuery: query);
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      fetchLists();
    });
  }

  void onFilterChanged(String filter) {
    state = state.copyWith(currentFilter: filter);
    fetchLists();
  }

  Future<void> fetchLists() async {
    state = state.copyWith(status: AdminListStatus.loading);
    try {
      final lists = await _repository.fetchLists(
        query: state.searchQuery,
        filterStatut: state.currentFilter,
      );
      state = state.copyWith(status: AdminListStatus.success, lists: lists);
    } catch (e) {
      state = state.copyWith(
        status: AdminListStatus.error,
        errorMessage: 'Erreur au chargement des listes: ${e.toString()}',
      );
    }
  }

  Future<void> archiveList(String listId) async {
    state = state.copyWith(status: AdminListStatus.loading);
    try {
      await _repository.updateListStatus(listId, 'ARCHIVEE');
      await fetchLists(); // Recharger pour appliquer les filtres et avoir la date d'archivage exacte DB
    } catch (e) {
      state = state.copyWith(
        status: AdminListStatus.error,
        errorMessage: 'Échec de l\'archivage: ${e.toString()}',
      );
    }
  }

  Future<void> deleteList(String listId) async {
    state = state.copyWith(status: AdminListStatus.loading);
    try {
      await _repository.deleteList(listId);
      final updatedLists = state.lists.where((l) => l.id != listId).toList();
      state = state.copyWith(status: AdminListStatus.success, lists: updatedLists);
    } catch (e) {
      state = state.copyWith(
        status: AdminListStatus.error,
        errorMessage: 'Impossible de supprimer cette liste: ${e.toString()}',
      );
    }
  }

  void resetStatus() {
    state = state.copyWith(status: AdminListStatus.initial, errorMessage: null);
  }
}
