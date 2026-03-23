import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:go_router/go_router.dart';

import '../domain/profile_notifier.dart';
import '../domain/profile_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isEditingName = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    final state = ref.read(profileNotifierProvider);
    if (state.displayName != null) {
      _nameController.text = state.displayName!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        if (!mounted) return;
        ref.read(profileNotifierProvider.notifier).uploadAvatar(File(image.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Action annulée ou erreur sur l'image")),
      );
    }
  }

  void _saveName() {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty) {
      ref.read(profileNotifierProvider.notifier).updateDisplayName(newName);
      setState(() {
        _isEditingName = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Le nom ne peut pas être vide")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileNotifierProvider);
    final user = Supabase.instance.client.auth.currentUser;

    ref.listen<ProfileState>(profileNotifierProvider, (previous, next) {
      if (next.status == ProfileStatus.success && previous?.status != ProfileStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour avec succès')),
        );
        ref.read(profileNotifierProvider.notifier).resetStatus();
      } else if (next.status == ProfileStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? 'Erreur'),
            backgroundColor: AppTheme.error,
          ),
        );
        ref.read(profileNotifierProvider.notifier).resetStatus();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil utilisateur'),
      ),
      body: user == null
          ? const Center(child: Text("Utilisateur non connecté"))
          : SingleChildScrollView(
              padding: EdgeInsets.all(AppTheme.padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  // Avatar Section
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        backgroundImage: profileState.avatarUrl != null && profileState.avatarUrl!.isNotEmpty
                            ? CachedNetworkImageProvider(profileState.avatarUrl!)
                            : null,
                        child: profileState.avatarUrl == null || profileState.avatarUrl!.isEmpty
                            ? Icon(Icons.person, size: 60, color: AppTheme.primary)
                            : null,
                      ),
                      if (profileState.status == ProfileStatus.loading)
                        const Positioned.fill(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: (profileState.status == ProfileStatus.loading) ? null : _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Email Section (Non editable)
                  _buildReadOnlyField(
                    label: 'Email',
                    value: user.email ?? 'Aucun email',
                    icon: Icons.email_outlined,
                  ),

                  const SizedBox(height: 20),

                  // Display Name Section
                  _buildEditableNameField(profileState),

                  if (profileState.isAdmin) ...[
                    const SizedBox(height: 30),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => context.pushNamed(AppRouteName.adminDashboard),
                        icon: const Icon(Icons.admin_panel_settings),
                        label: const Text('Aller au tableau de bord Admin', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 60),
                  
                  // Delete Account Action
                  OutlinedButton.icon(
                    onPressed: () => _showDeleteAccountDialog(user.email ?? ''),
                    icon: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
                    label: Text('Supprimer mon compte', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Theme.of(context).colorScheme.error),
                    ),
                  ),

                ],
              ),
            ),
    );
  }

  Future<void> _showDeleteAccountDialog(String expectedEmail) async {
    String typedEmail = '';
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          scrollable: true,
          title: const Text('Supprimer définitivement ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cette action est irréversible. Toutes vos listes et contributions seront effacées (ou anonymisées).'),
              const SizedBox(height: 16),
              Text('Veuillez saisir votre email ($expectedEmail) pour confirmer :'),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Email de confirmation',
                ),
                onChanged: (val) => typedEmail = val,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (typedEmail.trim() == expectedEmail) {
                  Navigator.pop(context);
                  ref.read(profileNotifierProvider.notifier).deleteAccount();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('L\'email saisi ne correspond pas')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                minimumSize: const Size(120, 48), // Empêche le bouton de prendre toute la largeur
              ),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReadOnlyField({required String label, required String value, required IconData icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: Theme.of(context).colorScheme.surfaceVariant),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.textSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ),
              Icon(Icons.lock_outline, size: 16, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditableNameField(ProfileState state) {
    if (!_isEditingName) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nom d\'affichage',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: Theme.of(context).colorScheme.surfaceVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.person_outline, color: AppTheme.textSecondary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.displayName ?? 'Aucun nom défini',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isEditingName = true;
                      _nameController.text = state.displayName ?? '';
                    });
                  },
                  child: Icon(Icons.edit_outlined, size: 20, color: AppTheme.primary),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Edit Mode
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Modifier le nom',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.primary),
            ),
            GestureDetector(
              onTap: () {
                setState(() => _isEditingName = false);
              },
              child: Text(
                'Annuler',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.error),
              ),
            )
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Votre nom...',
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
            ),
            const SizedBox(width: 12),
            state.status == ProfileStatus.loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _saveName,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      minimumSize: const Size(0, 50),
                    ),
                    child: const Text('Sauver'),
                  ),
          ],
        )
      ],
    );
  }
}
