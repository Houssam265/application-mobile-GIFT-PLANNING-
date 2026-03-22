import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository();
});

class NotificationsUiState {
  const NotificationsUiState({
    this.unreadCount = 0,
    this.pendingToast,
  });

  final int unreadCount;
  final String? pendingToast;

  NotificationsUiState copyWith({
    int? unreadCount,
    String? pendingToast,
    bool clearPendingToast = false,
  }) {
    return NotificationsUiState(
      unreadCount: unreadCount ?? this.unreadCount,
      pendingToast: clearPendingToast ? null : (pendingToast ?? this.pendingToast),
    );
  }
}

/// GP-19 : compteur non lu, toast sur insert Realtime, abonnement `notifications`.
class NotificationsNotifier extends StateNotifier<NotificationsUiState> {
  NotificationsNotifier(this._repo) : super(const NotificationsUiState());

  final NotificationsRepository _repo;
  RealtimeChannel? _channel;

  Future<void> bind() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await refreshUnreadCount();
    if (_channel != null) return;
    _subscribe(user.id);
  }

  void unbind() {
    _channel?.unsubscribe();
    _channel = null;
    state = const NotificationsUiState();
  }

  Future<void> refreshUnreadCount() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final n = await _repo.countUnread(user.id);
      state = state.copyWith(unreadCount: n);
    } catch (e) {
      debugPrint('refreshUnreadCount: $e');
    }
  }

  void clearPendingToast() {
    state = state.copyWith(clearPendingToast: true);
  }

  void _subscribe(String userId) {
    _channel?.unsubscribe();

    _channel = Supabase.instance.client
        .channel('notifications_user_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'utilisateur_id',
            value: userId,
          ),
          callback: _onPostgresChange,
        )
        .subscribe();
  }

  void _onPostgresChange(PostgresChangePayload payload) {
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        final row = payload.newRecord;
        final estLue = row['est_lue'] as bool? ?? false;
        final msg = row['message'] as String? ?? '';
        if (!estLue) {
          state = state.copyWith(
            unreadCount: state.unreadCount + 1,
            pendingToast: msg.isEmpty ? 'Nouvelle notification' : msg,
          );
        }
        break;
      case PostgresChangeEvent.update:
      case PostgresChangeEvent.delete:
        unawaited(refreshUnreadCount());
        break;
      case PostgresChangeEvent.all:
        break;
    }
  }
}

final notificationsNotifierProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsUiState>((ref) {
  final repo = ref.watch(notificationsRepositoryProvider);
  final notifier = NotificationsNotifier(repo);
  ref.onDispose(() {
    notifier.unbind();
  });
  return notifier;
});
