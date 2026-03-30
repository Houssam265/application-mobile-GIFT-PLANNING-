import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> insertInAppNotification({
  required String userId,
  required String type,
  required String message,
  bool isRead = false,
  DateTime? sentAt,
  String? action,
  String? listId,
  String? productId,
  String? suggestionId,
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  final legacyPayload = <String, dynamic>{
    'utilisateur_id': userId,
    'type': type,
    'message': message,
    'est_lue': isRead,
    if (sentAt != null) 'date_envoi': sentAt.toIso8601String(),
  };

  final payload = <String, dynamic>{
    ...legacyPayload,
    if (action != null && action.isNotEmpty) 'action': action,
    if (listId != null && listId.isNotEmpty) 'liste_id': listId,
    if (productId != null && productId.isNotEmpty) 'produit_id': productId,
    if (suggestionId != null && suggestionId.isNotEmpty)
      'suggestion_id': suggestionId,
  };

  try {
    await db.from('notifications').insert(payload);
  } catch (_) {
    await db.from('notifications').insert(legacyPayload);
  }
}
