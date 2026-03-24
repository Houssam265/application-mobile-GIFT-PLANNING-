import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../products/domain/product_model.dart';
import '../../products/domain/product_notifier.dart';

import '../domain/contribution_model.dart';
import '../domain/contribution_notifier.dart';

class ContributeScreen extends ConsumerStatefulWidget {
  const ContributeScreen({
    super.key,
    required this.productId,
  });

  final String productId;

  @override
  ConsumerState<ContributeScreen> createState() => _ContributeScreenState();
}

class _ContributeScreenState extends ConsumerState<ContributeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  bool _isLoading = true;
  ProductModel? _product;
  ContributionModel? _existingContribution;

  double _alreadyPromisedByOthers = 0.0;
  double _remaining = 0.0;

  DateTime? _eventDate;
  String? _listOwnerId;

  bool get _isEditing => _existingContribution != null;
  bool get _canModifyContribution {
    if (!_isEditing) return true;
    if (_eventDate == null) return true;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay =
        DateTime(_eventDate!.year, _eventDate!.month, _eventDate!.day);

    // Editable only if today < event date (strict).
    return today.isBefore(eventDay);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double? _tryParseAmount(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final productRepo = ref.read(productRepositoryProvider);
    final contributionRepo = ref.read(contributionRepositoryProvider);

    final product = await productRepo.getProductById(widget.productId);
    final existing =
        await contributionRepo.getUserContributionForProduct(widget.productId, user.id);

    final allContributions =
        await contributionRepo.getContributionsForProduct(widget.productId);
    final activeContributions =
        allContributions.where((c) => !c.estAnnulee).toList();

    final totalActive = activeContributions.fold<double>(
      0.0,
      (sum, c) => sum + c.montant,
    );

    final existingAmount = existing?.montant ?? 0.0;
    final alreadyPromisedByOthers = totalActive - existingAmount;
    final remaining = (product.prixCible - alreadyPromisedByOthers).clamp(
      0.0,
      double.infinity,
    );

    final listRes = await Supabase.instance.client
        .from('listes')
        .select('date_evenement, proprietaire_id')
        .eq('id', product.listeId)
        .maybeSingle();

    DateTime? eventDate;
    String? listOwnerId;
    if (listRes != null) {
      final dateRaw = listRes['date_evenement'];
      if (dateRaw is DateTime) {
        eventDate = dateRaw;
      } else if (dateRaw is String) {
        // Parse DATE-only string (YYYY-MM-DD) without timezone surprises.
        final parts = dateRaw.split('-');
        if (parts.length == 3) {
          final y = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 1;
          final d = int.tryParse(parts[2]) ?? 1;
          if (y > 0) eventDate = DateTime(y, m, d);
        }
      }
      listOwnerId =
          listRes['proprietaire_id'] as String?;
    }

    _amountController.text =
        existingAmount > 0 ? existingAmount.toStringAsFixed(2) : '';

    setState(() {
      _product = product;
      _existingContribution = existing;
      _alreadyPromisedByOthers = alreadyPromisedByOthers;
      _remaining = remaining;
      _eventDate = eventDate;
      _listOwnerId = listOwnerId;
      _isLoading = false;
    });
  }

  Future<void> _submit() async {
    if (_product == null) return;
    if (!_formKey.currentState!.validate()) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final amount = _tryParseAmount(_amountController.text);
    if (amount == null) return;

    await ref.read(contributionFormProvider.notifier).submitContribution(
          listId: _product!.listeId,
          productId: _product!.id,
          userId: user.id,
          amount: amount,
          existingContribution: _existingContribution,
        );
  }

  Future<void> _cancelContribution() async {
    if (_product == null || _existingContribution == null) return;
    if (!_canModifyContribution) return;
    if (_listOwnerId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler ma contribution ?'),
        content: const Text(
          'Cette action annule votre promesse (aucun paiement réel). Voulez-vous continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Retour'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Annuler la contribution'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Re-fetch product to ensure we know statut_financement BEFORE cancelling.
    final productRepo = ref.read(productRepositoryProvider);
    final productBefore = await productRepo.getProductById(_product!.id);
    final wasFinance = productBefore.statutFinancement == StatutFinancement.finance;

    try {
      await ref
          .read(contributionRepositoryProvider)
          .cancelContribution(_existingContribution!.id);

      if (wasFinance) {
        final msg =
            '${productBefore.nom} est repassé sous les 100% de financement après l’annulation de votre contribution.';

        await Supabase.instance.client.from('notifications').insert({
          'utilisateur_id': _listOwnerId,
          'type': 'CONTRIBUTION',
          'message': msg,
          'est_lue': false,
        });

        await ref.read(contributionRepositoryProvider).invokeFundingDroppedPush(
              listId: _product!.listeId,
              productId: _product!.id,
            );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l’annulation : $e')),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contribution annulée.')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(contributionFormProvider);

    ref.listen(contributionFormProvider, (previous, next) {
      if (next.status == ContributionFormStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Contribution mise à jour avec succès.'
                  : 'Contribution promise avec succès.',
            ),
          ),
        );

        ref.read(contributionFormProvider.notifier).reset();
        if (context.canPop()) context.pop();
      }

      if (next.status == ContributionFormStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? 'Une erreur est survenue.'),
          ),
        );
      }
    });

    if (_isLoading || _product == null) {
      return const Scaffold(
        body: Center(child: LoadingWidget(message: 'Chargement...')),
      );
    }

    final alreadyPromised = _alreadyPromisedByOthers;
    final remaining = _remaining;
    final totalPromised = alreadyPromised + (_existingContribution?.montant ?? 0.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Mettre à jour une contribution' : 'Contribuer'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _product!.nom,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Prix cible', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text('${_product!.prixCible.toStringAsFixed(2)} €'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Déjà promis', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text('${alreadyPromised.toStringAsFixed(2)} €'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Reste', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '${remaining.toStringAsFixed(2)} €',
                          style: TextStyle(
                            color: remaining <= 0.0 ? AppTheme.error : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Promesse totale (vos contributions incl.) : ${totalPromised.toStringAsFixed(2)} €',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_isEditing && !_canModifyContribution)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Contribution (lecture seule)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Montant promis : ${_existingContribution!.montant.toStringAsFixed(2)} €',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'L\'événement est passé, cette contribution n\'est plus modifiable.',
                        style: const TextStyle(
                          color: AppTheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                AppCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          controller: _amountController,
                          label: 'Montant promis',
                          hint: 'Ex : 25',
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          prefixIcon:
                              const Icon(Icons.euro_outlined),
                          enabled: formState.status !=
                              ContributionFormStatus.loading,
                          validator: (value) {
                            final raw = value?.trim() ?? '';
                            final parsed = _tryParseAmount(raw);
                            if (raw.isEmpty) {
                              return 'Merci d\'entrer un montant.';
                            }
                            if (parsed == null) {
                              return 'Montant invalide.';
                            }
                            if (parsed < 1) {
                              return 'Minimum : 1 €';
                            }
                            if (parsed > remaining) {
                              return 'Maximum : ${remaining.toStringAsFixed(2)} €';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: _isEditing ? 'Mettre à jour' : 'Promettre',
                          onPressed: formState.status ==
                                      ContributionFormStatus.loading ||
                                  remaining < 1
                              ? null
                              : _submit,
                          isLoading: formState.status ==
                              ContributionFormStatus.loading,
                          variant: AppButtonVariant.primary,
                        ),
                        if (_isEditing && _canModifyContribution)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: AppButton(
                              label: 'Annuler ma contribution',
                              onPressed: formState.status ==
                                      ContributionFormStatus.loading
                                  ? null
                                  : _cancelContribution,
                              variant: AppButtonVariant.secondary,
                              fullWidth: false,
                            ),
                          ),
                        if (remaining < 1)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'Ce produit est déjà (presque) entièrement financé.',
                              style: TextStyle(
                                color: AppTheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
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

