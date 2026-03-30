import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/notification_model.dart';

class NotificationsRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<NotificationModel>> fetchNotifications(String userId) async {
    final rows = await _client
        .from('notifications')
        .select()
        .eq('utilisateur_id', userId)
        .order('date_envoi', ascending: false);

    return (rows as List)
        .map((e) => NotificationModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> countUnread(String userId) async {
    final rows = await _client
        .from('notifications')
        .select('id')
        .eq('utilisateur_id', userId)
        .eq('est_lue', false);
    return (rows as List).length;
  }

  Future<void> setRead(String notificationId, String userId, bool read) async {
    await _client
        .from('notifications')
        .update({'est_lue': read})
        .eq('id', notificationId)
        .eq('utilisateur_id', userId);
  }

  Future<void> markAllRead(String userId) async {
    await _client
        .from('notifications')
        .update({'est_lue': true})
        .eq('utilisateur_id', userId)
        .eq('est_lue', false);
  }

  Future<void> deleteNotification(String notificationId, String userId) async {
    await _client
        .from('notifications')
        .delete()
        .eq('id', notificationId)
        .eq('utilisateur_id', userId);
  }

  Future<void> deleteNotifications(List<String> notificationIds, String userId) async {
    if (notificationIds.isEmpty) return;
    await _client
        .from('notifications')
        .delete()
        .eq('utilisateur_id', userId)
        .inFilter('id', notificationIds);
  }
}
