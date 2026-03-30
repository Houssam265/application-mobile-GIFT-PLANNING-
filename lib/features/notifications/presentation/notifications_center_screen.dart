import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/notification_model.dart';
import '../domain/notifications_notifier.dart';

/// GP-19 — Centre de notifications : liste horodatée, lu / non lu.
class NotificationsCenterScreen extends ConsumerStatefulWidget {
  const NotificationsCenterScreen({super.key});

  @override
  ConsumerState<NotificationsCenterScreen> createState() =>
      _NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState
    extends ConsumerState<NotificationsCenterScreen> {
  List<NotificationModel> _items = [];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _notificationsChannel;
  Timer? _reloadTimer;

  @override
  void initState() {
    super.initState();
    _bindRealtime();
    _load();
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    _notificationsChannel?.unsubscribe();
    super.dispose();
  }

  void _queueReload() {
    _reloadTimer?.cancel();
    _reloadTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _load();
    });
  }

  void _bindRealtime() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _notificationsChannel = Supabase.instance.client
        .channel('notifications_center_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'utilisateur_id',
            value: user.id,
          ),
          callback: (payload) {
            _queueReload();
          },
        )
        .subscribe();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Non connecté';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(notificationsRepositoryProvider);
      final list = await repo.fetchNotifications(user.id);
      if (mounted) {
        setState(() {
          _items = list;
          _loading = false;
        });
      }
      await ref.read(notificationsNotifierProvider.notifier).refreshUnreadCount();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _markAllRead() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead(user.id);
      setState(() {
        _items = _items.map((e) => e.copyWith(estLue: true)).toList();
      });
      await ref.read(notificationsNotifierProvider.notifier).refreshUnreadCount();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  Future<void> _toggleRead(NotificationModel n) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final next = !n.estLue;
    try {
      await ref.read(notificationsRepositoryProvider).setRead(n.id, user.id, next);
      setState(() {
        _items = _items
            .map((e) => e.id == n.id ? e.copyWith(estLue: next) : e)
            .toList();
      });
      await ref.read(notificationsNotifierProvider.notifier).refreshUnreadCount();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String _formatDate(DateTime d) {
    return '${_twoDigits(d.day)}/${_twoDigits(d.month)}/${d.year} '
        '${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'FINANCEMENT':
        return 'Financement';
      case 'ARCHIVAGE':
        return 'Archivage';
      case 'SUGGESTION':
        return 'Suggestion';
      case 'RAPPEL':
        return 'Rappel';
      case 'CONTRIBUTION':
        return 'Contribution';
      case 'ADHESION':
        return 'Adhésion';
      default:
        return type;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'FINANCEMENT':
        return Icons.savings_outlined;
      case 'ARCHIVAGE':
        return Icons.archive_outlined;
      case 'SUGGESTION':
        return Icons.lightbulb_outline;
      case 'RAPPEL':
        return Icons.schedule;
      case 'CONTRIBUTION':
        return Icons.volunteer_activism_outlined;
      case 'ADHESION':
        return Icons.person_add_alt_1_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _items.any((e) => !e.estLue);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Tout lu'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E86AB)))
          : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune notification.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFF2E86AB),
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        itemCount: _items.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final n = _items[index];
                          return Card(
                            elevation: 0,
                            color: n.estLue ? Colors.white : const Color(0xFFE8F4FA),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _toggleRead(n),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: const Color(0xFF2E86AB).withValues(alpha: 0.12),
                                      child: Icon(
                                        _typeIcon(n.type),
                                        color: const Color(0xFF2E86AB),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1E3A5F)
                                                      .withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  _typeLabel(n.type),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF1E3A5F),
                                                  ),
                                                ),
                                              ),
                                              if (!n.estLue) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFFDC2626),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            n.message,
                                            style: TextStyle(
                                              fontSize: 15,
                                              height: 1.35,
                                              fontWeight:
                                                  n.estLue ? FontWeight.w400 : FontWeight.w600,
                                              color: const Color(0xFF1E3A5F),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _formatDate(n.dateEnvoi),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: n.estLue ? 'Marquer non lu' : 'Marquer lu',
                                      icon: Icon(
                                        n.estLue
                                            ? Icons.mark_email_unread_outlined
                                            : Icons.mark_email_read_outlined,
                                        color: Colors.grey.shade700,
                                      ),
                                      onPressed: () => _toggleRead(n),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
