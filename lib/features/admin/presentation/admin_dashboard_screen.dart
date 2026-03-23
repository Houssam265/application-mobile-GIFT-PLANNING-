import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../profile/domain/profile_notifier.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileNotifierProvider);
    
    // Quick security check
    if (!profileState.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Accès refusé')),
        body: const Center(
          child: Text('Vous n\'avez pas les droits d\'administration.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.grey),
            onPressed: () => Supabase.instance.client.auth.signOut(),
            tooltip: 'Se déconnecter',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.people, color: Colors.indigo),
              title: const Text('Gestion des utilisateurs', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Rechercher, suspendre ou supprimer des comptes.'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                context.pushNamed('admin-users');
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.featured_play_list, color: Colors.blue),
              title: const Text('Gestion des listes', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Voir toutes les listes, forcer l\'archivage, modération.'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                context.pushNamed('admin-lists');
              },
            ),
          ),
          // D'autres tuiles (Stats) viendront ici plus tard
        ],
      ),
    );
  }
}
