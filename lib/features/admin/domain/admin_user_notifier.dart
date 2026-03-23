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
      final users = await _repository.fetchUsers(q);
      state = state.copyWith(status: AdminUserStatus.success, users: users);
    } catch (e) {
      state = state.copyWith(
        status: AdminUserStatus.error,
        errorMessage: 'Erreur au chargement des utilisateurs: ${e.toString()}',
      );
    }
  }

  Future<void> toggleUserSuspension(String userId, bool nouveauStatutSuspendu) async {
    state = state.copyWith(status: AdminUserStatus.loading);
    try {
      await _repository.updateUserStatus(userId, nouveauStatutSuspendu);
      
      // Mettre à jour la liste locale sans tout recharger
      final updatedUsers = state.users.map((u) {
        if (u.id == userId) {
          return u.copyWith(estSuspendu: nouveauStatutSuspendu);
        }
        return u;
      }).toList();
      
      state = state.copyWith(status: AdminUserStatus.success, users: updatedUsers);
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
