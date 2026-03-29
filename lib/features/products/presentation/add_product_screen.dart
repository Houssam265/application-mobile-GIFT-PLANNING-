import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_widget.dart';
import '../domain/product_model.dart';
import '../domain/product_notifier.dart';

/// Used for both add and edit.
/// Pass [existingProduct] to enter edit mode.
class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({
    super.key,
    required this.listId,
    this.existingProduct,
  });

  final String listId;
  final ProductModel? existingProduct;

  bool get isEditing => existingProduct != null;

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nomController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _prixController;
  late final TextEditingController _lienController;

  ProductCategorie? _categorie;
  XFile? _imageFile;
  Uint8List? _imagePreview;

  final _imagePicker = ImagePicker();
  bool _isListArchived = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProduct;
    _nomController = TextEditingController(text: p?.nom ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _prixController = TextEditingController(
      text: p != null ? p.prixCible.toStringAsFixed(2) : '',
    );
    _lienController = TextEditingController(text: p?.lienUrl ?? '');
    _categorie = p?.categorie;
    _loadListMeta();
  }

  Future<void> _loadListMeta() async {
    try {
      final row = await Supabase.instance.client
          .from('listes')
          .select('statut')
          .eq('id', widget.listId)
          .maybeSingle();
      setState(() {
        _isListArchived = (row?['statut'] as String?) == 'ARCHIVEE';
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nomController.dispose();
    _descriptionController.dispose();
    _prixController.dispose();
    _lienController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      setState(() {
        _imageFile = image;
        _imagePreview = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de sélectionner la photo : $e')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isListArchived) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Liste archivée — ajout/modification désactivés.')),
      );
      return;
    }

    final prix = double.tryParse(
      _prixController.text.trim().replaceAll(',', '.'),
    );
    if (prix == null || prix <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merci d\'entrer un prix valide.')),
      );
      return;
    }

    final notifier = ref.read(productFormProvider.notifier);

    if (widget.isEditing) {
      await notifier.updateProduct(
        productId: widget.existingProduct!.id,
        nom: _nomController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        prixCible: prix,
        imageBytes: _imagePreview,
        imageFileName: _imageFile?.name,
        lienUrl: _lienController.text.trim().isEmpty
            ? null
            : _lienController.text.trim(),
        categorie: _categorie,
      );
    } else {
      await notifier.addProduct(
        listeId: widget.listId,
        nom: _nomController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        prixCible: prix,
        imageBytes: _imagePreview,
        imageFileName: _imageFile?.name,
        lienUrl: _lienController.text.trim().isEmpty
            ? null
            : _lienController.text.trim(),
        categorie: _categorie,
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce produit ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await ref
        .read(productFormProvider.notifier)
        .deleteProduct(widget.existingProduct!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(productFormProvider);

    ref.listen(productFormProvider, (_, next) {
      if (next.status == ProductFormStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? 'Produit mis à jour avec succès !'
                  : 'Produit ajouté avec succès !',
            ),
          ),
        );
        ref.read(productFormProvider.notifier).reset();
        context.pop();
      } else if (next.status == ProductFormStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? 'Une erreur est survenue.'),
          ),
        );
        ref.read(productFormProvider.notifier).reset();
      }
    });

    final isLoading = state.status == ProductFormStatus.loading;
    final existingImageUrl = widget.existingProduct?.imageUrl;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Modifier le produit' : 'Ajouter un produit',
        ),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
              tooltip: 'Supprimer ce produit',
              onPressed: isLoading ? null : _confirmDelete,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.padding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isListArchived)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Liste archivée', style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(height: 8),
                        Text(
                          'Les modifications et ajouts de produits sont désactivés.',
                          style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                if (_isListArchived) const SizedBox(height: 16),
                // ── Informations principales ─────────────────────────
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Informations principales',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _nomController,
                        label: 'Nom du produit *',
                        hint: 'Ex : AirPods Pro',
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Le nom est obligatoire.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _descriptionController,
                        label: 'Description (optionnelle)',
                        hint: 'Détails, couleur, taille...',
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Prix & catégorie ─────────────────────────────────
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Prix & catégorie',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _prixController,
                        label: 'Prix cible *',
                        hint: '59.99',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        prefixIcon: const Icon(Icons.euro_outlined),
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Le prix est obligatoire.';
                          }
                          final parsed = double.tryParse(
                              v.trim().replaceAll(',', '.'));
                          if (parsed == null || parsed <= 0) {
                            return 'Entrez un prix valide (ex : 29.99).';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ProductCategorie>(
                        initialValue: _categorie,
                        decoration: const InputDecoration(
                          labelText: 'Catégorie (optionnelle)',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: ProductCategorie.values
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c.label),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _categorie = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Image produit ────────────────────────────────────
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Image du produit (optionnelle)',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      if (_imagePreview != null) ...[
                        // New image picked locally
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                          child: Image.memory(
                            _imagePreview!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: 'Changer la photo',
                          onPressed: _pickImage,
                          variant: AppButtonVariant.secondary,
                          fullWidth: false,
                        ),
                      ] else if (existingImageUrl != null) ...[
                        // Existing image from Supabase (edit mode)
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                          child: CachedNetworkImage(
                            imageUrl: existingImageUrl,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: 'Changer la photo',
                          onPressed: _pickImage,
                          variant: AppButtonVariant.secondary,
                          fullWidth: false,
                        ),
                      ] else
                        EmptyState(
                          title: 'Aucune image sélectionnée',
                          message:
                              'Ajoute une image pour illustrer le produit.',
                          icon: Icons.image_outlined,
                          actionLabel: 'Choisir une photo',
                          onAction: _pickImage,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Lien boutique ────────────────────────────────────
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lien boutique (optionnel)',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _lienController,
                        label: 'URL du produit',
                        hint: 'https://www.amazon.fr/...',
                        keyboardType: TextInputType.url,
                        prefixIcon: const Icon(Icons.link_outlined),
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Submit ────────────────────────────────────────────
                if (isLoading)
                  LoadingWidget(
                    message: widget.isEditing
                        ? 'Mise à jour en cours...'
                        : 'Ajout du produit en cours...',
                  )
                else
                  AppButton(
                    label: widget.isEditing
                        ? 'Enregistrer les modifications'
                        : 'Ajouter le produit',
                    onPressed: _isListArchived ? null : _submit,
                    icon: widget.isEditing
                        ? Icons.save_outlined
                        : Icons.add_circle_outline,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
