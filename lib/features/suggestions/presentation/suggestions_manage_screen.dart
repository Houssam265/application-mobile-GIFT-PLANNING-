import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../products/domain/product_model.dart';
import '../domain/suggestion_model.dart';
import '../domain/suggestion_notifier.dart';

class SuggestionsManageScreen extends ConsumerStatefulWidget {
  const SuggestionsManageScreen({super.key, required this.listId});

  final String listId;

  @override
  ConsumerState<SuggestionsManageScreen> createState() => _SuggestionsManageScreenState();
}

class _SuggestionsManageScreenState extends ConsumerState<SuggestionsManageScreen> {
  bool _checkedOwner = false;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOwnerAndLoad();
    });
  }

  Future<void> _checkOwnerAndLoad() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _checkedOwner = true;
        _isOwner = false;
      });
      return;
    }

    final list = await Supabase.instance.client
        .from('listes')
        .select('proprietaire_id')
        .eq('id', widget.listId)
        .maybeSingle();

    final ownerId = list?['proprietaire_id'] as String?;
    if (!mounted) return;
    setState(() {
      _checkedOwner = true;
      _isOwner = ownerId == user.id;
    });

    if (_isOwner) {
      await ref.read(suggestionProvider.notifier).loadSuggestions(widget.listId);
    }
  }

  Future<void> _validateSuggestion(String suggestionId) async {
    await ref.read(suggestionProvider.notifier).validateSuggestion(
          suggestionId: suggestionId,
          listeId: widget.listId,
        );
  }

  Future<void> _refuseSuggestion(String suggestionId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser la suggestion'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Motif du refus *',
              hintText: 'Explique la raison du refus...',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Le motif est obligatoire.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Refuser'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      reasonController.dispose();
      return;
    }

    await ref.read(suggestionProvider.notifier).refuseSuggestion(
          suggestionId: suggestionId,
          userId: user.id,
          motifRefus: reasonController.text.trim(),
          listeId: widget.listId,
        );
    reasonController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(suggestionProvider);

    ref.listen(suggestionProvider, (_, next) {
      if (next.status == SuggestionFormStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage ?? 'Une erreur est survenue.')),
        );
      }
    });

    if (!_checkedOwner) {
      return const Scaffold(
        body: Center(child: LoadingWidget(message: 'Vérification des permissions...')),
      );
    }

    if (!_isOwner) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.padding),
            child: Text('Accès refusé : seul le propriétaire peut gérer les suggestions.'),
          ),
        ),
      );
    }

    final pendingSuggestions = state.suggestions
        .where((s) => s.statut == SuggestionStatus.enAttente)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Suggestions en attente')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(suggestionProvider.notifier).loadSuggestions(widget.listId),
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.padding),
            children: [
              if (state.status == SuggestionFormStatus.loading && state.suggestions.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: LoadingWidget(message: 'Chargement des suggestions...'),
                )
              else if (pendingSuggestions.isEmpty)
                AppCard(
                  child: Text(
                    'Aucune suggestion en attente.',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              else
                ...pendingSuggestions.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.nomProduit, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 6),
                          if (s.categorie != null)
                            Text(
                              'Catégorie: ${s.categorie!.label}',
                              style: theme.textTheme.bodySmall,
                            ),
                          Text(
                            'Prix cible: ${s.prixCible.toStringAsFixed(2)} €',
                            style: theme.textTheme.bodyMedium,
                          ),
                          if (s.description != null && s.description!.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(s.description!, style: theme.textTheme.bodyMedium),
                          ],
                          if (s.lienUrl != null && s.lienUrl!.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              s.lienUrl!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  label: 'Valider',
                                  icon: Icons.check_circle_outline,
                                  onPressed: () => _validateSuggestion(s.id),
                                  variant: AppButtonVariant.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: AppButton(
                                  label: 'Refuser',
                                  icon: Icons.cancel_outlined,
                                  onPressed: () => _refuseSuggestion(s.id),
                                  variant: AppButtonVariant.secondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
