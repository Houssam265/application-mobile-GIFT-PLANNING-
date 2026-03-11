import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import 'auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authNotifierProvider =
StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AuthState());

  Future<void> register(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repository.register(email: email, password: password);
      state = state.copyWith(status: AuthStatus.success);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repository.login(email: email, password: password);
      state = state.copyWith(status: AuthStatus.success);
    } catch (e) {
      String errorMessage = 'Erreur inattendue';
      final errorStr = e.toString().toLowerCase();
      
      if (errorStr.contains('invalid login credentials')) {
        errorMessage = 'Email ou mot de passe incorrect.';
      } else if (errorStr.contains('email not confirmed')) {
        errorMessage = 'Veuillez vérifier votre email avant de vous connecter.';
      } else {
        errorMessage = e.toString();
      }

      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: errorMessage,
      );
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repository.sendPasswordResetEmail(email);
      state = state.copyWith(status: AuthStatus.success);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Erreur Supabase : ${e.toString()}',
      );
    }
  }

  Future<void> updatePassword(String newPassword) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repository.updatePassword(newPassword);
      state = state.copyWith(status: AuthStatus.success);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Échec de la mise à jour du mot de passe.',
      );
    }
  }
}