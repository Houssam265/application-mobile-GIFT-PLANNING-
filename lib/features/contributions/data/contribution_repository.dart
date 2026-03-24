import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../products/domain/product_model.dart';
import '../domain/contribution_model.dart';

class ContributionRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> _invokeContributionPush(Map<String, dynamic> body) async {
    try {
      await Supabase.instance.client.auth.refreshSession();
      final token =
          Supabase.instance.client.auth.currentSession?.accessToken ?? '';
      if (token.isEmpty) return;
      await _client.functions.invoke(
        'participant-notifications',
        body: body,
        headers: {
          'Authorization': 'Bearer $token',
          'apikey': SupabaseConstants.supabaseAnonKey,
        },
      );
    } catch (e) {
      debugPrint('participant-notifications (contribution): $e');
    }
  }

  /// Push OneSignal après annulation ayant fait repasser un produit sous 100 % (notif in-app déjà insérée).
  Future<void> invokeFundingDroppedPush({
    required String listId,
    required String productId,
  }) async {
    await _invokeContributionPush({
      'action': 'product_funding_dropped',
      'listId': listId,
      'productId': productId,
    });
  }

  Future<void> _notifyOwnerIfJustFullyFunded({
    required String productId,
    required String productName,
    required String listId,
    required bool wasFinanceBefore,
  }) async {
    if (wasFinanceBefore) return;

    final latest = await _client
        .from('produits')
        .select('statut_financement')
        .eq('id', productId)
        .maybeSingle();

    if (latest == null) return;
    final statut = (latest['statut_financement'] as String?) ?? 'NON_FINANCE';
    if (statut != StatutFinancement.finance.dbValue) return;

    final list = await _client
        .from('listes')
        .select('proprietaire_id')
        .eq('id', listId)
        .maybeSingle();

    final ownerId = list?['proprietaire_id'] as String?;
    if (ownerId == null || ownerId.isEmpty) return;

    await _client.from('notifications').insert({
      'utilisateur_id': ownerId,
      'type': 'FINANCEMENT',
      'message': 'Le produit "$productName" est entièrement financé !',
      'est_lue': false,
    });

    await _invokeContributionPush({
      'action': 'product_fully_funded',
      'listId': listId,
      'productId': productId,
    });
  }

  Future<void> _notifyOwnerNewContribution({
    required String listId,
    required String productId,
    required String contributorId,
    required String productName,
    required double amount,
    required bool isUpdate,
  }) async {
    final list = await _client
        .from('listes')
        .select('proprietaire_id')
        .eq('id', listId)
        .maybeSingle();
    final ownerId = list?['proprietaire_id'] as String?;
    if (ownerId == null || ownerId.isEmpty || ownerId == contributorId) {
      return;
    }

    final userRow = await _client
        .from('utilisateurs')
        .select('nom')
        .eq('id', contributorId)
        .maybeSingle();
    final name = (userRow?['nom'] as String?) ?? 'Un participant';
    final msg = isUpdate
        ? '$name a ajusté sa promesse à ${amount.toStringAsFixed(2)}€ pour « $productName ».'
        : '$name a promis ${amount.toStringAsFixed(2)}€ pour « $productName ».';

    await _client.from('notifications').insert({
      'utilisateur_id': ownerId,
      'type': 'CONTRIBUTION',
      'message': msg,
      'est_lue': false,
    });

    await _invokeContributionPush({
      'action': 'contribution_received',
      'listId': listId,
      'productId': productId,
    });
  }

  Future<ContributionModel?> getUserContributionForProduct(
    String productId,
    String userId,
  ) async {
    final res = await _client
        .from('contributions')
        .select()
        .eq('produit_id', productId)
        .eq('utilisateur_id', userId)
        .eq('est_annulee', false)
        .order('date_promesse', ascending: false)
        .limit(1)
        .maybeSingle();

    if (res == null) return null;
    return ContributionModel.fromMap(res);
  }

  Future<List<ContributionModel>> getContributionsForProduct(
    String productId,
  ) async {
    final res = await _client
        .from('contributions')
        .select()
        .eq('produit_id', productId)
        .order('date_promesse', ascending: true);

    return (res as List)
        .map((e) => ContributionModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<double> _sumActiveContributionsForProduct(String productId) async {
    final res = await _client
        .from('contributions')
        .select('montant')
        .eq('produit_id', productId)
        .eq('est_annulee', false);

    return (res as List).fold<double>(0.0, (sum, row) {
      final montantRaw = (row as Map<String, dynamic>)['montant'];
      final montant = montantRaw is num
          ? montantRaw.toDouble()
          : double.tryParse(montantRaw?.toString() ?? '') ?? 0.0;
      return sum + montant;
    });
  }

  StatutFinancement _calculateStatutFinancement({
    required double totalPromised,
    required double prixCible,
  }) {
    if (totalPromised <= 0) return StatutFinancement.nonFinance;
    if (totalPromised >= prixCible) return StatutFinancement.finance;
    return StatutFinancement.partiellementFinance;
  }

  Future<void> _recalculateProductFinancing({
    required String productId,
  }) async {
    final product = await _client
        .from('produits')
        .select('id, prix_cible')
        .eq('id', productId)
        .maybeSingle();

    if (product == null) return;

    final prixRaw = product['prix_cible'];
    final prixCible =
        prixRaw is num ? prixRaw.toDouble() : double.tryParse(prixRaw?.toString() ?? '') ?? 0.0;

    final totalPromised = await _sumActiveContributionsForProduct(productId);
    final calculatedStatus = _calculateStatutFinancement(
      totalPromised: totalPromised,
      prixCible: prixCible,
    );

    await _client.from('produits').update({
      'statut_financement': calculatedStatus.dbValue,
      'date_modification': DateTime.now().toIso8601String(),
    }).eq('id', productId);
  }

  Future<double> _fetchMaxAllowedAmountForUser({
    required String listId,
    required String productId,
    double? userCurrentAmount,
  }) async {
    final product = await _client
        .from('produits')
        .select('prix_cible')
        .eq('id', productId)
        .eq('liste_id', listId)
        .maybeSingle();

    if (product == null) {
      throw Exception('Produit introuvable pour cette liste.');
    }

    final prixRaw = product['prix_cible'];
    final prixCible =
        prixRaw is num ? prixRaw.toDouble() : double.tryParse(prixRaw?.toString() ?? '') ?? 0.0;

    final totalActive = await _sumActiveContributionsForProduct(productId);
    final existingAmount = userCurrentAmount ?? 0.0;
    final othersSum = totalActive - existingAmount;
    final maxAllowed = (prixCible - othersSum).clamp(0.0, double.infinity);
    return maxAllowed;
  }

  Future<ContributionModel> addContribution({
    required String listId,
    required String productId,
    required String userId,
    required double amount,
  }) async {
    final productBefore = await _client
        .from('produits')
        .select('id, nom, liste_id, statut_financement')
        .eq('id', productId)
        .maybeSingle();

    final wasFinanceBefore = ((productBefore?['statut_financement'] as String?) ??
            StatutFinancement.nonFinance.dbValue) ==
        StatutFinancement.finance.dbValue;
    final productNameBefore = (productBefore?['nom'] as String?) ?? 'Produit';
    final effectiveListId = (productBefore?['liste_id'] as String?) ?? listId;

    final existing = await getUserContributionForProduct(productId, userId);

    final maxAllowed = await _fetchMaxAllowedAmountForUser(
      listId: listId,
      productId: productId,
      userCurrentAmount: existing?.montant ?? 0.0,
    );

    if (amount < 1) {
      throw Exception('Le montant minimum est de 1.');
    }
    if (amount > maxAllowed) {
      throw Exception(
        'Le montant dépasse le reste disponible (${maxAllowed.toStringAsFixed(2)}€).',
      );
    }

    // Ensure "one contribution per participant per product" by updating the existing row.
    if (existing != null) {
      return updateContribution(existing.id, amount);
    }

    final response = await _client
        .from('contributions')
        .insert({
          'produit_id': productId,
          'utilisateur_id': userId,
          'montant': amount,
          'est_annulee': false,
        })
        .select()
        .single();

    final contribution = ContributionModel.fromMap(response);

    await _recalculateProductFinancing(productId: productId);
    await _notifyOwnerIfJustFullyFunded(
      productId: productId,
      productName: productNameBefore,
      listId: effectiveListId,
      wasFinanceBefore: wasFinanceBefore,
    );
    await _notifyOwnerNewContribution(
      listId: effectiveListId,
      productId: productId,
      contributorId: userId,
      productName: productNameBefore,
      amount: amount,
      isUpdate: false,
    );
    return contribution;
  }

  Future<ContributionModel> updateContribution(
    String contributionId,
    double newAmount,
  ) async {
    final current = await _client
        .from('contributions')
        .select('id, produit_id, utilisateur_id, montant, est_annulee')
        .eq('id', contributionId)
        .maybeSingle();

    if (current == null) {
      throw Exception('Contribution introuvable.');
    }

    final produitId = current['produit_id'] as String;
    final oldAmountRaw = current['montant'];
    final oldAmount =
        oldAmountRaw is num ? oldAmountRaw.toDouble() : double.tryParse(oldAmountRaw?.toString() ?? '') ?? 0.0;

    // Validate max allowed amount for the updated contribution.
    final product = await _client
        .from('produits')
        .select('liste_id, prix_cible')
        .eq('id', produitId)
        .maybeSingle();

    if (product == null) {
      throw Exception('Produit introuvable.');
    }

    final listId = product['liste_id'] as String;

    final maxAllowed = await _fetchMaxAllowedAmountForUser(
      listId: listId,
      productId: produitId,
      userCurrentAmount: oldAmount,
    );

    if (newAmount < 1) {
      throw Exception('Le montant minimum est de 1.');
    }
    if (newAmount > maxAllowed) {
      throw Exception(
        'Le montant dépasse le reste disponible (${maxAllowed.toStringAsFixed(2)}€).',
      );
    }

    final productBefore = await _client
        .from('produits')
        .select('id, nom, liste_id, statut_financement')
        .eq('id', produitId)
        .maybeSingle();

    final wasFinanceBefore = ((productBefore?['statut_financement'] as String?) ??
            StatutFinancement.nonFinance.dbValue) ==
        StatutFinancement.finance.dbValue;
    final productNameBefore = (productBefore?['nom'] as String?) ?? 'Produit';
    final listIdForNotif = (productBefore?['liste_id'] as String?) ?? listId;

    final response = await _client
        .from('contributions')
        .update({
          'montant': newAmount,
          'est_annulee': false,
          'date_modification': DateTime.now().toIso8601String(),
        })
        .eq('id', contributionId)
        .select()
        .single();

    final updated = ContributionModel.fromMap(response);

    await _recalculateProductFinancing(productId: produitId);
    await _notifyOwnerIfJustFullyFunded(
      productId: produitId,
      productName: productNameBefore,
      listId: listIdForNotif,
      wasFinanceBefore: wasFinanceBefore,
    );
    final contributorId = current['utilisateur_id'] as String;
    await _notifyOwnerNewContribution(
      listId: listIdForNotif,
      productId: produitId,
      contributorId: contributorId,
      productName: productNameBefore,
      amount: newAmount,
      isUpdate: true,
    );
    return updated;
  }

  Future<void> cancelContribution(String contributionId) async {
    final current = await _client
        .from('contributions')
        .select('id, produit_id')
        .eq('id', contributionId)
        .maybeSingle();

    if (current == null) return;

    final produitId = current['produit_id'] as String;

    try {
      await _client.from('contributions').update({
        'est_annulee': true,
        'date_modification': DateTime.now().toIso8601String(),
      }).eq('id', contributionId);
    } catch (e) {
      // Cancel is best-effort; we still try to recalculate.
      debugPrint('Failed to cancel contribution: $e');
    }

    await _recalculateProductFinancing(productId: produitId);
  }
}

