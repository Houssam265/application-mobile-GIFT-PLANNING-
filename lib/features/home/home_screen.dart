import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/router/app_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _lists = [];
  String? _selectedListId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchLists();
  }

  Future<void> _fetchLists() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final data = await Supabase.instance.client
        .from('listes')
        .select('id, titre')
        .eq('proprietaire_id', user.id)
        .order('date_creation', ascending: false);

    setState(() {
      _lists = List<Map<String, dynamic>>.from(data as List);
      _selectedListId = _lists.isNotEmpty ? _lists.first['id'] as String : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Créer une liste ───────────────────────────────────
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Créer une liste'),
                onPressed: () => context.pushNamed(AppRouteName.listCreate),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // ── Ouvrir une liste existante ────────────────────────
              const Text(
                'Accéder à une liste',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (_loading)
                const LinearProgressIndicator()
              else if (_lists.isEmpty)
                const Text(
                  'Aucune liste trouvée.',
                  style: TextStyle(color: Colors.grey),
                )
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedListId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: _lists
                      .map(
                        (l) => DropdownMenuItem<String>(
                          value: l['id'] as String,
                          child: Text(l['titre'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedListId = v),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _selectedListId == null
                      ? null
                      : () => context.pushNamed(
                            AppRouteName.listDetail,
                            pathParameters: {'id': _selectedListId!},
                          ),
                  child: const Text('Ouvrir la liste'),
                ),
              ],
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // ── Déconnexion ───────────────────────────────────────
              TextButton(
                onPressed: () =>
                    Supabase.instance.client.auth.signOut(),
                child: const Text('Se déconnecter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
