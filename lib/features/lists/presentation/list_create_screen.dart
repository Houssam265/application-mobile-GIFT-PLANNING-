import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/empty_state.dart';
import '../../lists/data/list_repository.dart';

class ListCreateScreen extends StatefulWidget {
  const ListCreateScreen({super.key});

  @override
  State<ListCreateScreen> createState() => _ListCreateScreenState();
}

class _ListCreateScreenState extends State<ListCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _eventNameController = TextEditingController();

  DateTime? _eventDate;
  ListVisibility _visibility = ListVisibility.public;

  XFile? _coverFile;
  Uint8List? _coverBytesPreview;

  bool _isSubmitting = false;

  final _imagePicker = ImagePicker();
  final _repository = ListRepository();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _eventNameController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();

      setState(() {
        _coverFile = image;
        _coverBytesPreview = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de sélectionner la photo : $e'),
        ),
      );
    }
  }

  Future<void> _selectEventDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );

    if (picked != null) {
      setState(() {
        _eventDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_eventDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Merci de choisir la date de l’événement.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      Uint8List? coverBytes;
      String? coverFileName;

      if (_coverFile != null) {
        coverBytes = _coverBytesPreview ?? await _coverFile!.readAsBytes();
        coverFileName = _coverFile!.name;
      }

      final listId = await _repository.createList(
        titre: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        nomEvenement: _eventNameController.text.trim(),
        dateEvenement: _eventDate!,
        couvertureBytes: coverBytes,
        couvertureFileName: coverFileName,
        visibility: _visibility,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Liste créée avec succès !'),
        ),
      );

      // Rediriger vers le détail de la liste ou le dashboard des listes.
      context.goNamed(AppRouteName.listDetail, pathParameters: {'id': listId});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la création de la liste : $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle liste de souhaits'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.padding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                        controller: _titleController,
                        label: 'Titre de la liste *',
                        hint: 'Anniversaire de Sophie',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Le titre est obligatoire.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _descriptionController,
                        label: 'Description (optionnelle)',
                        hint: 'Détails supplémentaires sur la liste...',
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Événement',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _eventNameController,
                        label: 'Nom de l’événement *',
                        hint: 'Anniversaire, Mariage, Crémaillère...',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Le nom de l’événement est obligatoire.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _selectEventDate,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date de l’événement *',
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _eventDate == null
                                    ? 'Choisir une date'
                                    : '${_eventDate!.day.toString().padLeft(2, '0')}/'
                                        '${_eventDate!.month.toString().padLeft(2, '0')}/'
                                        '${_eventDate!.year}',
                                style: _eventDate == null
                                    ? theme.textTheme.bodyMedium
                                    : theme.textTheme.bodyLarge,
                              ),
                              const Icon(Icons.calendar_today_outlined, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Photo de couverture (optionnelle)',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      if (_coverBytesPreview != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          child: Image.memory(
                            _coverBytesPreview!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        EmptyState(
                          title: 'Aucune image sélectionnée',
                          message: 'Ajoute une belle image pour illustrer ta liste.',
                          icon: Icons.image_outlined,
                          actionLabel: 'Choisir une photo',
                          onAction: _pickCoverImage,
                        ),
                      if (_coverBytesPreview != null) ...[
                        const SizedBox(height: 12),
                        AppButton(
                          label: 'Changer la photo',
                          onPressed: _pickCoverImage,
                          variant: AppButtonVariant.secondary,
                          fullWidth: false,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Visibilité des contributions',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choisis comment les contributions seront visibles pour les participants.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: [
                          RadioListTile<ListVisibility>(
                            value: ListVisibility.public,
                            groupValue: _visibility,
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _visibility = value);
                            },
                            title: const Text('Public'),
                            subtitle: const Text(
                              'Tous les participants voient les montants et les noms des contributeurs.',
                            ),
                          ),
                          RadioListTile<ListVisibility>(
                            value: ListVisibility.private,
                            groupValue: _visibility,
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _visibility = value);
                            },
                            title: const Text('Privé'),
                            subtitle: const Text(
                              'Seul le propriétaire voit les détails, les autres voient uniquement le total.',
                            ),
                          ),
                          RadioListTile<ListVisibility>(
                            value: ListVisibility.anonymous,
                            groupValue: _visibility,
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _visibility = value);
                            },
                            title: const Text('Anonyme'),
                            subtitle: const Text(
                              'Les montants sont visibles mais les noms des contributeurs sont masqués.',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_isSubmitting)
                  const LoadingWidget(message: 'Création de la liste en cours...')
                else
                  AppButton(
                    label: 'Créer la liste',
                    onPressed: _submit,
                    variant: AppButtonVariant.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

