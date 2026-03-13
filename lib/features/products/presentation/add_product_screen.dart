import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_widget.dart';
import '../domain/product_model.dart';
import '../domain/product_notifier.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key, required this.listId});

  final String listId;

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nomController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prixController = TextEditingController();
  final _lienController = TextEditingController();

  ProductCategorie? _categorie;
  XFile? _imageFile;
  Uint8List? _imagePreview;

  final _imagePicker = ImagePicker();

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

    final prix = double.tryParse(
      _prixController.text.trim().replaceAll(',', '.'),
    );
    if (prix == null || prix <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merci d\'entrer un prix valide.')),
      );
      return;
    }

    await ref.read(addProductProvider.notifier).addProduct(
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(addProductProvider);

    // React to state changes.
    ref.listen(addProductProvider, (_, next) {
      if (next.status == AddProductStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produit ajouté avec succès !')),
        );
        ref.read(addProductProvider.notifier).reset();
        context.pop(); // Back to list detail
      } else if (next.status == AddProductStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? 'Une erreur est survenue.'),
          ),
        );
        ref.read(addProductProvider.notifier).reset();
      }
    });

    final isLoading = state.status == AddProductStatus.loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un produit'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.padding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Informations principales ─────────────────────────
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informations principales',
                        style: theme.textTheme.titleMedium,
                      ),
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
                      Text(
                        'Prix & catégorie',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _prixController,
                        label: 'Prix cible *',
                        hint: '59.99',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        prefixIcon: const Icon(Icons.euro_outlined),
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Le prix est obligatoire.';
                          }
                          final parsed = double.tryParse(
                            v.trim().replaceAll(',', '.'),
                          );
                          if (parsed == null || parsed <= 0) {
                            return 'Entrez un prix valide (ex : 29.99).';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ProductCategorie>(
                        value: _categorie,
                        decoration: const InputDecoration(
                          labelText: 'Catégorie (optionnelle)',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: ProductCategorie.values
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.label),
                              ),
                            )
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
                      Text(
                        'Image du produit (optionnelle)',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      if (_imagePreview != null) ...[
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
                      ] else
                        EmptyState(
                          title: 'Aucune image sélectionnée',
                          message: 'Ajoute une image pour illustrer le produit.',
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
                      Text(
                        'Lien boutique (optionnel)',
                        style: theme.textTheme.titleMedium,
                      ),
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
                  const LoadingWidget(
                    message: 'Ajout du produit en cours...',
                  )
                else
                  AppButton(
                    label: 'Ajouter le produit',
                    onPressed: _submit,
                    icon: Icons.add_circle_outline,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
