import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/admin_user_model.dart';
import '../domain/admin_user_notifier.dart';
import '../domain/admin_user_state.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Force a fresh fetch from DB every time this screen becomes active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(adminUserNotifierProvider);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminUserNotifierProvider);

    ref.listen<AdminUserState>(adminUserNotifierProvider, (previous, next) {
      if (next.status == AdminUserStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppTheme.error,
          ),
        );
        ref.read(adminUserNotifierProvider.notifier).resetStatus();
      } else if (next.actionSucceeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action effectuée avec succès.')),
        );
        ref.read(adminUserNotifierProvider.notifier).resetStatus();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des utilisateurs'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou email...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(adminUserNotifierProvider.notifier).onSearchQueryChanged('');
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                ref.read(adminUserNotifierProvider.notifier).onSearchQueryChanged(value);
              },
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('TOUT', 'Tous (${state.totalUsers})', state.currentFilter),
                const SizedBox(width: 8),
                _buildFilterChip('ACTIFS', 'Actifs (${state.activeUsers})', state.currentFilter),
                const SizedBox(width: 8),
                _buildFilterChip('SUSPENDUS', 'Suspendus (${state.suspendedUsers})', state.currentFilter),
              ],
            ),
          ),

          // Loading indicator
          if (state.status == AdminUserStatus.loading)
            const LinearProgressIndicator(),

          // User List
          Expanded(
            child: state.users.isEmpty && state.status != AdminUserStatus.loading
                ? const Center(child: Text('Aucun utilisateur trouvé.'))
                : RefreshIndicator(
                    onRefresh: () => ref.read(adminUserNotifierProvider.notifier).fetchUsers(),
                    child: ListView.builder(
                      itemCount: state.users.length,
                      itemBuilder: (context, index) {
                        final user = state.users[index];
                        final isSuspended = user.estSuspendu;
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          elevation: 1,
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: isSuspended ? AppTheme.error.withOpacity(0.2) : AppTheme.primary.withOpacity(0.1),
                              backgroundImage: user.photoProfilUrl != null && user.photoProfilUrl!.isNotEmpty
                                  ? NetworkImage(user.photoProfilUrl!)
                                  : null,
                              child: user.photoProfilUrl == null || user.photoProfilUrl!.isEmpty
                                  ? Icon(
                                      isSuspended ? Icons.person_off : Icons.person,
                                      color: isSuspended ? AppTheme.error : AppTheme.primary,
                                    )
                                  : null,
                            ),
                            title: Text(
                              user.nom,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: isSuspended ? TextDecoration.lineThrough : null,
                                color: isSuspended ? Colors.grey : Colors.black87,
                              ),
                            ),
                            subtitle: Text(user.email),
                            trailing: user.estAdministrateur
                                ? const Chip(
                                    label: Text('ADMIN', style: TextStyle(fontSize: 10, color: Colors.white)),
                                    backgroundColor: Colors.indigo,
                                    visualDensity: VisualDensity.compact,
                                  )
                                : null,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (user.dateInscription != null) 
                                      Text('Inscrit le : ${user.dateInscription!.day.toString().padLeft(2, '0')}/${user.dateInscription!.month.toString().padLeft(2, '0')}/${user.dateInscription!.year} ${user.dateInscription!.hour.toString().padLeft(2, '0')}:${user.dateInscription!.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        if (!user.estAdministrateur)
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isSuspended ? Colors.green : Colors.orange,
                                              foregroundColor: Colors.white,
                                            ),
                                            icon: Icon(isSuspended ? Icons.play_arrow : Icons.pause),
                                            label: Text(isSuspended ? 'Réactiver' : 'Suspendre'),
                                            onPressed: () {
                                              ref.read(adminUserNotifierProvider.notifier).toggleUserSuspension(user.id, !isSuspended);
                                            },
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }


  Widget _buildFilterChip(String value, String label, String currentFilter) {
    final isSelected = currentFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          ref.read(adminUserNotifierProvider.notifier).onFilterChanged(value);
        }
      },
      selectedColor: AppTheme.primary.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primary : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
