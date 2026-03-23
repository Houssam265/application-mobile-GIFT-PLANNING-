import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_user_repository.dart';
import 'admin_user_state.dart';

final adminUserRepositoryProvider = Provider<AdminUserRepository>((ref) {
  return AdminUserRepository();
});

final adminUserNotifierProvider =
    StateNotifierProvider<AdminUserNotifier, AdminUserState>((ref) {
  return AdminUserNotifier(ref.read(adminUserRepositoryProvider));
});

class AdminUserNotifier extends StateNotifier<AdminUserState> {
  final AdminUserRepository _repository;
  Timer? _debounceTimer;

  AdminUserNotifier(this._repository) : super(const AdminUserState()) {
    fetchUsers();
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
      fetchUsers(query: query);
    });
  }

  Future<void> fetchUsers({String? query}) async {
    state = state.copyWith(status: AdminUserStatus.loading);
    try {
      final q = query ?? state.searchQuery;
      
      bool? isSuspended;
      if (state.currentFilter == 'ACTIFS') isSuspended = false;
      if (state.currentFilter == 'SUSPENDUS') isSuspended = true;

      final users = await _repository.fetchUsers(q, isSuspended: isSuspended);
      
      // Also fetch stats to keep them fresh
      final stats = await _repository.fetchUserStats();
      
      state = state.copyWith(
        status: AdminUserStatus.success, 
        users: users,
        totalUsers: stats['total'] ?? 0,
        activeUsers: stats['active'] ?? 0,
        suspendedUsers: stats['suspended'] ?? 0,
      );
    } catch (e) {
      state = state.copyWith(
        status: AdminUserStatus.error,
        errorMessage: 'Erreur au chargement des utilisateurs: ${e.toString()}',
      );
    }
  }

  void onFilterChanged(String filter) {
    state = state.copyWith(currentFilter: filter);
    fetchUsers();
  }

  Future<void> toggleUserSuspension(String userId, bool nouveauStatutSuspendu) async {
    state = state.copyWith(status: AdminUserStatus.loading);
    try {
      await _repository.updateUserStatus(userId, nouveauStatutSuspendu);
      
      // Refresh both list and stats
      await fetchUsers();
    } catch (e) {
      state = state.copyWith(
        status: AdminUserStatus.error,
        errorMessage: 'Échec de modification du statut: ${e.toString()}',
      );
    }
  }

  void resetStatus() {
    state = state.copyWith(status: AdminUserStatus.initial, errorMessage: null);
  }
}
