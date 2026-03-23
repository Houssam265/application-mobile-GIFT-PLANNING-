import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      body: const Center(
        child: Text('Le tableau de bord admin sera implémenté ici.'),
      ),
    );
  }
}
