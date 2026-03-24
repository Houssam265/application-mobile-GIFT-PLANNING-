import 'package:jwt_decode/jwt_decode.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Indique si la session JWT actuelle provient du flux « mot de passe oublié »
/// (claim [amr] avec `method: recovery`). Dans ce cas l’utilisateur doit
/// impérativement passer par [ResetPasswordScreen] avant le reste de l’app.
bool isPasswordRecoverySession(Session? session) {
  if (session == null) return false;
  try {
    final payload = Jwt.parseJwt(session.accessToken);
    final amr = payload['amr'];
    if (amr is List) {
      for (final item in amr) {
        if (item is Map && item['method'] == 'recovery') return true;
        if (item == 'recovery') return true;
      }
    }
  } catch (_) {
    return false;
  }
  return false;
}
