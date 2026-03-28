import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/admin_list_model.dart';
import '../domain/admin_list_notifier.dart';
import '../domain/admin_list_state.dart';

class AdminListsScreen extends ConsumerStatefulWidget {
  const AdminListsScreen({super.key});

  @override
  ConsumerState<AdminListsScreen> createState() => _AdminListsScreenState();
}

class _AdminListsScreenState extends ConsumerState<AdminListsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Force a fresh fetch from DB every time this screen becomes active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(adminListNotifierProvider);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showArchiveConfirmation(BuildContext context, AdminListModel list) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Forcer l\'archivage'),
          content: Text('Voulez-vous vraiment clore et archiver la liste "${list.titre}" ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(adminListNotifierProvider.notifier).archiveList(list.id);
              },
              child: const Text('Archiver'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, AdminListModel list) {
    String typedTitle = '';
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Danger: Suppression Liste (Inappropriée)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pour confirmer l\'effacement, tapez le titre exact de la liste :'),
              const SizedBox(height: 8),
              Text(list.titre, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Titre de la liste',
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.error),
                  ),
                ),
                onChanged: (val) => typedTitle = val,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () {
                if (typedTitle.trim() == list.titre) {
                  Navigator.pop(ctx);
                  ref.read(adminListNotifierProvider.notifier).deleteList(list.id);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Le titre saisi ne correspond pas.')),
                  );
                }
              },
              child: const Text('Détruire'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminListNotifierProvider);

    ref.listen<AdminListState>(adminListNotifierProvider, (previous, next) {
      if (next.status == AdminListStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppTheme.error,
          ),
        );
        ref.read(adminListNotifierProvider.notifier).resetStatus();
      } else if (next.status == AdminListStatus.success && previous?.status != AdminListStatus.success && previous!.status != AdminListStatus.initial) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action effectuée avec succès.')),
        );
        ref.read(adminListNotifierProvider.notifier).resetStatus();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des listes'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par titre ou évènement...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(adminListNotifierProvider.notifier).onSearchQueryChanged('');
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                ref.read(adminListNotifierProvider.notifier).onSearchQueryChanged(value);
              },
            ),
          ),

          // Filtres Statut
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('TOUTES', 'Toutes (${state.totalLists})', state.currentFilter),
                const SizedBox(width: 8),
                _buildFilterChip('ACTIVE', 'Actives (${state.activeLists})', state.currentFilter),
                const SizedBox(width: 8),
                _buildFilterChip('ARCHIVEE', 'Archivées (${state.archivedLists})', state.currentFilter),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Loading indicator
          if (state.status == AdminListStatus.loading)
            const LinearProgressIndicator(),

          // User List
          Expanded(
            child: state.lists.isEmpty && state.status != AdminListStatus.loading
                ? const Center(child: Text('Aucune liste trouvée.'))
                : RefreshIndicator(
                    onRefresh: () => ref.read(adminListNotifierProvider.notifier).fetchLists(),
                    child: ListView.builder(
                      itemCount: state.lists.length,
                      itemBuilder: (context, index) {
                        final list = state.lists[index];
                        final isArchived = list.statut == 'ARCHIVEE';
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          elevation: 1,
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: isArchived ? Colors.grey.withOpacity(0.2) : AppTheme.primary.withOpacity(0.1),
                              child: Icon(
                                isArchived ? Icons.inventory_2 : Icons.card_giftcard,
                                color: isArchived ? Colors.grey : AppTheme.primary,
                              ),
                            ),
                            title: Text(
                              list.titre,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isArchived ? Colors.grey : Colors.black87,
                              ),
                            ),
                            subtitle: Text('Propriétaire: ${list.proprietaireNom}\nEvénement: ${list.nomEvenement}'),
                            trailing: Chip(
                                label: Text(isArchived ? 'ARCHIVÉE' : 'ACTIVE', style: const TextStyle(fontSize: 10, color: Colors.white)),
                                backgroundColor: isArchived ? Colors.grey : Colors.green,
                                visualDensity: VisualDensity.compact,
                              ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text('Email Proprio : ${list.proprietaireEmail}', style: const TextStyle(fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text('Créée le : ${list.dateCreation.day.toString().padLeft(2, '0')}/${list.dateCreation.month.toString().padLeft(2, '0')}/${list.dateCreation.year}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    if (isArchived && list.dateArchivage != null)
                                      Text('Archivée le : ${list.dateArchivage!.day.toString().padLeft(2, '0')}/${list.dateArchivage!.month.toString().padLeft(2, '0')}/${list.dateArchivage!.year}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        if (!isArchived)
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange,
                                              foregroundColor: Colors.white,
                                            ),
                                            icon: const Icon(Icons.archive),
                                            label: const Text('Forcer Archivage'),
                                            onPressed: () => _showArchiveConfirmation(context, list),
                                          ),
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.error,
                                            side: BorderSide(color: AppTheme.error),
                                          ),
                                          icon: const Icon(Icons.delete_forever),
                                          label: const Text('Supprimer (Inapproprié)'),
                                          onPressed: () => _showDeleteConfirmation(context, list),
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
          ref.read(adminListNotifierProvider.notifier).onFilterChanged(value);
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
