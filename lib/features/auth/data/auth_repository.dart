import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';



class AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> register({
    required String email,
    required String password,
  }) async {
    // Contournement bug Supabase Web: on force une URL de prod explicite
    // Si on passe null, le SDK Flutter injecte automatiquement "http://localhost:..." 
    // ce qui fait crasher le serveur (erreur 500) à cause des wildcards.
    final redirectTo = kIsWeb ? 'https://giftplan.rf.gd' : 'giftplan://login-callback/';
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: redirectTo,
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
  Future<void> sendPasswordResetEmail(String email) async {
    // Contournement bug Supabase: l'API Crash (500) si on passe null car le SDK Flutter injecte 
    // le localhost. On force avec une URL du site par défaut explicitly (giftplan.rf.gd).
    final redirectTo = kIsWeb
        ? 'https://giftplan.rf.gd/reset-password'
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
    final redirectTo = kIsWeb ? '${Uri.base.origin}/' : 'giftplan://login-callback/';
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
    );
  }

  Future<void> signInWithFacebook() async {
    // Redirige vers la page web Facebook, puis revient sur l'app mobile via le deep link
    final redirectTo = kIsWeb ? '${Uri.base.origin}/' : 'giftplan://login-callback/';
    await _client.auth.signInWithOAuth(
      OAuthProvider.facebook,
      redirectTo: redirectTo,
    );
  }
}