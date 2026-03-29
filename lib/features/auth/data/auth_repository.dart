import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> register({
    required String email,
    required String password,
  }) async {
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

  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<void> verifyRecoveryCode({
    required String email,
    required String code,
  }) async {
    await _client.auth.verifyOTP(
      email: email,
      token: code,
      type: OtpType.recovery,
    );
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> signInWithGoogle() async {
    final redirectTo = kIsWeb ? '${Uri.base.origin}/' : 'giftplan://login-callback/';
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
    );
  }

  Future<void> signInWithFacebook() async {
    final redirectTo = kIsWeb ? '${Uri.base.origin}/' : 'giftplan://login-callback/';
    await _client.auth.signInWithOAuth(
      OAuthProvider.facebook,
      redirectTo: redirectTo,
    );
  }
}
