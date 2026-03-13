import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../lists/data/list_repository.dart';
import '../../products/domain/product_model.dart';

class ListDetailScreen extends StatefulWidget {
  const ListDetailScreen({super.key, required this.listId});

  final String listId;

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  final _repository = ListRepository();
  final _imagePicker = ImagePicker();

  Map<String, dynamic>? _listData;
  bool _isLoading = true;
  bool _isSaving = false;

  // État édition
  bool _isEditing = false;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _eventNameController;
  DateTime? _eventDate;
  ListVisibility _visibility = ListVisibility.public;

  Uint8List? _newCoverBytes;
  String? _newCoverFileName;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _eventNameController = TextEditingController();
    _loadList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _eventNameController.dispose();
    super.dispose();
  }

  Future<void> _loadList() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _repository.getListById(widget.listId);

      _listData = data;
      _titleController.text = data['titre'] as String? ?? '';
      _descriptionController.text = data['description'] as String? ?? '';
      _eventNameController.text = data['nom_evenement'] as String? ?? '';

      final dateStr = data['date_evenement']?.toString();
      if (dateStr != null) {
        _eventDate = DateTime.tryParse(dateStr);
      }

      final visibilityStr =
          data['visibilite_contributions'] as String? ?? 'PUBLIC';
      _visibility = visibilityFromDb(visibilityStr);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement de la liste : $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool get _isOwner {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _listData == null) return false;
    return _listData!['proprietaire_id'] == user.id;
  }

  Future<void> _pickNewCover() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      setState(() {
        _newCoverBytes = bytes;
        _newCoverFileName = picked.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de sélectionner la photo : $e')),
      );
    }
  }

  Future<void> _selectEventDate() async {
    final now = DateTime.now();
    final initial = _eventDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );

    if (picked != null) {
      setState(() {
        _eventDate = picked;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_eventDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci de choisir la date de l’événement.'),
        ),
      );
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le titre est obligatoire.')),
      );
      return;
    }

    if (_eventNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom de l’événement est obligatoire.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.updateList(
        id: widget.listId,
        titre: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        nomEvenement: _eventNameController.text.trim(),
        dateEvenement: _eventDate!,
        couvertureBytes: _newCoverBytes,
        couvertureFileName: _newCoverFileName,
        visibility: _visibility,
      );

      _newCoverBytes = null;
      _newCoverFileName = null;

      await _loadList();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Liste mise à jour avec succès.')),
      );

      setState(() {
        _isEditing = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour : $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _leaveList() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter la liste'),
        content: const Text('Êtes-vous sûr de vouloir quitter cette liste ? Vous ne pourrez plus y accéder sans une nouvelle invitation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      try {
        await Supabase.instance.client
            .from('participations')
            .delete()
            .eq('liste_id', widget.listId)
            .eq('utilisateur_id', user.id);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vous avez quitté la liste.')),
        );
        context.go('/home');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading || _listData == null) {
      return const Scaffold(
        body: Center(
          child: LoadingWidget(message: 'Chargement de la liste...'),
        ),
      );
    }

    final isArchived = (_listData?['statut'] as String?) == 'ARCHIVEE';
    final dateEvenement = _eventDate ?? DateTime.now();
    final now = DateTime.now();
    final daysRemaining = dateEvenement
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;

    return Scaffold(
      appBar: AppBar(
        title: Text(_listData?['titre'] as String? ?? 'Détail de la liste'),
        actions: [
          if (_isOwner) ...[
            IconButton(
              icon: const Icon(Icons.people_alt_outlined),
              tooltip: 'Gérer les participants',
              onPressed: () => context.pushNamed(
                AppRouteName.participantsManage,
                pathParameters: {'id': widget.listId},
              ),
            ),
            IconButton(
              icon: Icon(_isEditing ? Icons.close : Icons.edit),
              onPressed: _isSaving
                  ? null
                  : () {
                      setState(() {
                        _isEditing = !_isEditing;
                      });
                    },
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
              tooltip: 'Quitter la liste',
              onPressed: _leaveList,
            ),
          ],
        ],
      ),
      floatingActionButton: _isOwner && !_isEditing
          ? FloatingActionButton.extended(
              onPressed: () => context.pushNamed(
                AppRouteName.productAdd,
                pathParameters: {'listId': widget.listId},
              ),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un produit'),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderCard(theme, dateEvenement, daysRemaining, isArchived),
              const SizedBox(height: 16),
              _buildFundingCard(theme),
              const SizedBox(height: 16),
              _buildProductsCard(theme),
              if (_isOwner) ...[
                const SizedBox(height: 24),
                if (_isSaving)
                  const LoadingWidget(
                    message: 'Enregistrement des modifications...',
                  )
                else ...[
                  if (_isEditing)
                    AppButton(
                      label: 'Enregistrer les modifications',
                      onPressed: _saveChanges,
                      variant: AppButtonVariant.primary,
                    ),
                  if (!_isEditing) ...[
                    AppButton(
                      label: isArchived
                          ? 'Réactiver la liste'
                          : 'Archiver la liste',
                      onPressed: isArchived ? _reactivateList : _archiveList,
                      variant: AppButtonVariant.secondary,
                    ),
                    const SizedBox(height: 12),
                    if (isArchived)
                      AppButton(
                        label: 'Supprimer définitivement la liste',
                        onPressed: _deleteList,
                        variant: AppButtonVariant.text,
                      ),
                  ],
                ],
              ],
              const SizedBox(height: 80), // space for FAB
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    ThemeData theme,
    DateTime dateEvenement,
    int daysRemaining,
    bool isArchived,
  ) {
    final coverUrl = _listData?['photo_couverture_url'] as String?;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (coverUrl != null && _newCoverBytes == null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: CachedNetworkImage(
                imageUrl: coverUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else if (_newCoverBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: Image.memory(
                _newCoverBytes!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          if (_isOwner && !isArchived) ...[
            const SizedBox(height: 8),
            AppButton(
              label: coverUrl == null && _newCoverBytes == null
                  ? 'Ajouter une couverture'
                  : 'Modifier la couverture',
              onPressed: _pickNewCover,
              variant: AppButtonVariant.secondary,
              fullWidth: false,
            ),
          ],
          const SizedBox(height: 16),
          if (_isEditing) ...[
            AppTextField(
              controller: _titleController,
              label: 'Titre de la liste',
            ),
            const SizedBox(height: 8),
            AppTextField(
              controller: _descriptionController,
              label: 'Description',
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            AppTextField(
              controller: _eventNameController,
              label: 'Nom de l’événement',
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectEventDate,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date de l’événement',
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${dateEvenement.day.toString().padLeft(2, '0')}/'
                      '${dateEvenement.month.toString().padLeft(2, '0')}/'
                      '${dateEvenement.year}',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const Icon(Icons.calendar_today_outlined, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ListVisibility>(
              value: _visibility,
              decoration: const InputDecoration(
                labelText: 'Visibilité des contributions',
              ),
              items: const [
                DropdownMenuItem(
                  value: ListVisibility.public,
                  child: Text('Public'),
                ),
                DropdownMenuItem(
                  value: ListVisibility.private,
                  child: Text('Privé'),
                ),
                DropdownMenuItem(
                  value: ListVisibility.anonymous,
                  child: Text('Anonyme'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _visibility = value;
                });
              },
            ),
          ] else ...[
            Text(
              _listData?['titre'] as String? ?? '',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isArchived
                        ? theme.colorScheme.surfaceVariant
                        : theme.colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isArchived ? 'Archivée' : 'Active',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isArchived
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _listData?['description'] as String? ?? '',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.event, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${dateEvenement.day.toString().padLeft(2, '0')}/'
                  '${dateEvenement.month.toString().padLeft(2, '0')}/'
                  '${dateEvenement.year}',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.schedule, size: 18),
                const SizedBox(width: 6),
                Text(
                  daysRemaining > 0
                      ? '$daysRemaining jours restants'
                      : daysRemaining == 0
                      ? 'Événement aujourd’hui'
                      : 'Événement passé',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductsCard(ThemeData theme) {
    final productsStream = Supabase.instance.client
        .from('produits')
        .stream(primaryKey: ['id'])
        .eq('liste_id', widget.listId)
        .order('date_creation', ascending: true);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: productsStream,
      builder: (context, snapshot) {
        final products = snapshot.data ?? [];

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Produits (${products.length})',
                style: theme.textTheme.titleMedium,
              ),
              if (!snapshot.hasData)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(),
                )
              else if (products.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Aucun produit pour le moment.',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = products[index];
                    final productId = p['id'] as String;
                    final imageUrl = p['image_url'] as String?;
                    final prix =
                        double.tryParse(p['prix_cible'].toString()) ?? 0.0;
                    final cat = p['categorie'] as String?;
                    final currentStatus =
                        p['statut_financement'] as String? ??
                        StatutFinancement.nonFinance.dbValue;

                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: Supabase.instance.client
                          .from('contributions')
                          .stream(primaryKey: ['id'])
                          .eq('produit_id', productId),
                      builder: (context, contribSnapshot) {
                        final contributions = (contribSnapshot.data ?? [])
                            .where((c) => c['est_annulee'] != true)
                            .toList();
                        final double totalPromised = contributions.fold(
                          0.0,
                          (sum, c) =>
                              sum +
                              (double.tryParse(c['montant'].toString()) ?? 0.0),
                        );

                        final percentage = prix > 0
                            ? (totalPromised / prix).clamp(0.0, 1.0)
                            : 0.0;
                        final remaining = (prix - totalPromised).clamp(
                          0.0,
                          double.infinity,
                        );

                        Color progressColor;
                        StatutFinancement calculatedStatus;
                        if (percentage == 0) {
                          progressColor = Colors.red;
                          calculatedStatus = StatutFinancement.nonFinance;
                        } else if (percentage < 1) {
                          progressColor = Colors.orange;
                          calculatedStatus =
                              StatutFinancement.partiellementFinance;
                        } else {
                          progressColor = Colors.green;
                          calculatedStatus = StatutFinancement.finance;
                        }

                        // Fire and forget: update status in DB if it changed
                        if (currentStatus != calculatedStatus.dbValue) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            Supabase.instance.client
                                .from('produits')
                                .update({
                                  'statut_financement':
                                      calculatedStatus.dbValue,
                                })
                                .eq('id', productId);
                          });
                        }

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 4,
                          ),
                          leading: imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.inventory_2_outlined),
                                ),
                          title: Text(
                            p['nom'] as String? ?? '',
                            style: theme.textTheme.bodyLarge,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (cat != null)
                                Text(
                                  productCategorieFromDb(cat).label,
                                  style: theme.textTheme.bodySmall,
                                ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percentage,
                                  backgroundColor: progressColor.withOpacity(
                                    0.2,
                                  ),
                                  color: progressColor,
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${totalPromised.toStringAsFixed(2)} € / ${prix.toStringAsFixed(2)} €',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: progressColor,
                                    ),
                                  ),
                                  if (remaining > 0)
                                    Text(
                                      'Reste ${remaining.toStringAsFixed(2)} €',
                                      style: theme.textTheme.bodySmall,
                                    )
                                  else
                                    Text(
                                      'Complet !',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          onTap: _isOwner && !_isEditing
                              ? () {
                                  context.pushNamed(
                                    AppRouteName.productEdit,
                                    pathParameters: {
                                      'listId': widget.listId,
                                      'id': productId,
                                    },
                                    extra: ProductModel.fromMap(p),
                                  );
                                }
                              : null,
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFundingCard(ThemeData theme) {
    final client = Supabase.instance.client;

    final productsStream = client
        .from('produits')
        .stream(primaryKey: ['id'])
        .eq('liste_id', widget.listId);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: productsStream,
      builder: (context, snapshotProducts) {
        if (!snapshotProducts.hasData) {
          return const AppCard(
            child: LoadingWidget(message: 'Calcul du financement global...'),
          );
        }

        final products = snapshotProducts.data ?? [];
        if (products.isEmpty) {
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Financement global', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Aucun produit pour le moment. Ajoute des produits pour commencer le financement.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        final productIds = products.map((p) => p['id'] as String).toList();
        final totalTarget = products.fold<double>(
          0,
          (sum, p) => sum + (double.tryParse(p['prix_cible'].toString()) ?? 0),
        );

        final contributionsStream = client
            .from('contributions')
            .stream(primaryKey: ['id'])
            .inFilter('produit_id', productIds);

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: contributionsStream,
          builder: (context, snapshotContribs) {
            final contribs = snapshotContribs.data ?? [];
            final totalPromised = contribs
                .where((c) => c['est_annulee'] != true)
                .fold<double>(
                  0,
                  (sum, c) =>
                      sum + (double.tryParse(c['montant'].toString()) ?? 0),
                );

            final percent = totalTarget <= 0
                ? 0.0
                : (totalPromised / totalTarget * 100).clamp(0, 100);

            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Financement global',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: percent / 100,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${percent.toStringAsFixed(1)} % financé',
                        style: theme.textTheme.bodyLarge,
                      ),
                      Text(
                        '${totalPromised.toStringAsFixed(2)} / ${totalTarget.toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _archiveList() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archiver la liste ?'),
        content: const Text(
          'La liste sera déplacée dans les listes archivées. '
          'Les participants ne pourront plus y contribuer, mais les données seront conservées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _repository.archiveList(widget.listId);
      await _loadList();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l’archivage : $e')),
      );
    }
  }

  Future<void> _reactivateList() async {
    if (_eventDate == null) {
      await _selectEventDate();
      if (_eventDate == null) {
        return;
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Réactiver la liste ?'),
        content: const Text(
          'La liste sera réactivée avec la nouvelle date d’événement. '
          'Les participants pourront à nouveau contribuer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Réactiver'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _repository.reactivateList(
        id: widget.listId,
        newEventDate: _eventDate!,
      );
      await _loadList();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la réactivation : $e')),
      );
    }
  }

  Future<void> _deleteList() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer définitivement ?'),
        content: const Text(
          'Cette action est irréversible. La liste et toutes les données liées '
          '(produits, contributions, participations, suggestions, notifications) '
          'seront supprimées définitivement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _repository.deleteArchivedList(widget.listId);
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la suppression : $e')),
      );
    }
  }
}
