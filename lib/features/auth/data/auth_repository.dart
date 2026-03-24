import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_links.dart';

class AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> register({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: kIsWeb ? null : 'giftplan://login-callback/',
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

  /// Doit être autorisé dans Supabase Dashboard → Auth → URL de redirection :
  /// - `giftplan://reset-password`
  /// - `${AppLinks.baseUrl}/reset-password` (web)
  Future<void> sendPasswordResetEmail(String email) async {
    final redirectTo = kIsWeb
        ? '${AppLinks.baseUrl}/reset-password'
        : 'giftplan://reset-password';
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: redirectTo,
    );
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> signInWithGoogle() async {
    // Redirige vers la page web Google, puis revient sur l'app mobile via le deep link
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'giftplan://login-callback/',
    );
  }

  Future<void> signInWithFacebook() async {
    // Redirige vers la page web Facebook, puis revient sur l'app mobile via le deep link
    await _client.auth.signInWithOAuth(
      OAuthProvider.facebook,
      redirectTo: kIsWeb ? null : 'giftplan://login-callback/',
    );
  }
}