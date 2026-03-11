import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> register({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    if (response.user == null) {
      throw Exception('Inscription échouée. Vérifie ton email.');
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) {
      throw Exception('Connexion échouée. Vérifie tes identifiants.');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    // Demande l'envoi d'un email de réinitialisation.
    // L'ajout de redirectTo avec un custom scheme permet d'ouvrir l'application mobile.
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'giftplan://reset-callback/',
    );
  }

  Future<void> updatePassword(String newPassword) async {
    // Met à jour le mot de passe de l'utilisateur actuellement connecté
    // (cela fonctionne directement après le clic sur le lien de réinitialisation).
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }
}