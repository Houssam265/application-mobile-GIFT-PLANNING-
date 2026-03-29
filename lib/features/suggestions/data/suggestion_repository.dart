import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/services/storage_service.dart';
import '../../products/domain/product_model.dart';
import '../domain/suggestion_model.dart';

class SuggestionRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final _storage = StorageService();

  Future<void> _invokePush(Map<String, dynamic> body) async {
    try {
      try {
        await Supabase.instance.client.auth.refreshSession();
      } catch (_) {}
      final token = Supabase.instance.client.auth.currentSession?.accessToken ?? '';

      await _client.functions.invoke(
        'participant-notifications',
        body: body,
      );
    } catch (e) {
      debugPrint('participant-notifications: $e');
    }
  }

  Future<SuggestionModel> submitSuggestion({
    required String listeId,
    required String userId,
    required String nomProduit,
    String? description,
    required double prixCible,
    Uint8List? imageBytes,
    String? imageFileName,
    String? lienUrl,
    ProductCategorie? categorie,
  }) async {
    String? imageUrl;
    if (imageBytes != null && imageFileName != null) {
      imageUrl = await _storage.upload(
        bucket: StorageBucket.products,
        bytes: imageBytes,
        fileName: imageFileName,
        folder: userId,
      );
    }

    final payload = <String, dynamic>{
      'liste_id': listeId,
      'utilisateur_id': userId,
      'nom_produit': nomProduit,
      'description': description,
      'prix_cible': prixCible,
      'image_url': imageUrl,
      'lien_url': lienUrl?.isNotEmpty == true ? lienUrl : null,
      'categorie': categorie?.dbValue,
      'statut': SuggestionStatus.enAttente.dbValue,
    };

    final inserted = await _client
        .from('suggestions')
        .insert(payload)
        .select()
        .single();

    final list = await _client
        .from('listes')
        .select('proprietaire_id')
        .eq('id', listeId)
        .maybeSingle();
    final ownerId = list?['proprietaire_id'] as String?;
    if (ownerId != null && ownerId.isNotEmpty) {
      await _client.from('notifications').insert({
        'utilisateur_id': ownerId,
        'type': 'SUGGESTION',
        'message': 'Nouvelle suggestion de produit : "$nomProduit".',
        'est_lue': false,
      });
    }

    final model = SuggestionModel.fromJson(inserted);
    await _invokePush({
      'action': 'suggestion_created',
      'listId': listeId,
      'suggestionId': model.id,
    });

    return model;
  }

  Future<List<SuggestionModel>> getSuggestionsForList(String listeId) async {
    final response = await _client
        .from('suggestions')
        .select()
        .eq('liste_id', listeId)
        .order('date_suggestion', ascending: false);

    return (response as List)
        .map((e) => SuggestionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> validateSuggestion({
    required String suggestionId,
    required String listeId,
  }) async {
    final suggestion = await _client
        .from('suggestions')
        .select()
        .eq('id', suggestionId)
        .eq('liste_id', listeId)
        .maybeSingle();
    if (suggestion == null) {
      throw Exception('Suggestion introuvable.');
    }

    final nowIso = DateTime.now().toIso8601String();

    await _client.from('produits').insert({
      'liste_id': suggestion['liste_id'],
      'nom': suggestion['nom_produit'],
      'description': suggestion['description'],
      'prix_cible': suggestion['prix_cible'],
      'image_url': suggestion['image_url'],
      'lien_url': suggestion['lien_url'],
      'categorie': suggestion['categorie'],
      'statut_financement': StatutFinancement.nonFinance.dbValue,
    });

    await _client.from('suggestions').update({
      'statut': SuggestionStatus.validee.dbValue,
      'date_traitement': nowIso,
      'motif_refus': null,
    }).eq('id', suggestionId);

    final suggesterId = suggestion['utilisateur_id'] as String?;
    final nomProduit = suggestion['nom_produit'] as String? ?? 'Produit';
    if (suggesterId != null && suggesterId.isNotEmpty) {
      await _client.from('notifications').insert({
        'utilisateur_id': suggesterId,
        'type': 'SUGGESTION',
        'message': 'Votre suggestion "$nomProduit" a ete acceptee.',
        'est_lue': false,
      });
    }

    await _invokePush({
      'action': 'suggestion_accepted',
      'listId': listeId,
      'suggestionId': suggestionId,
    });
  }

  Future<void> refuseSuggestion({
    required String suggestionId,
    required String userId,
    required String motifRefus,
  }) async {
    final suggestion = await _client
        .from('suggestions')
        .select('id, utilisateur_id, nom_produit, liste_id')
        .eq('id', suggestionId)
        .maybeSingle();
    if (suggestion == null) {
      throw Exception('Suggestion introuvable.');
    }

    final list = await _client
        .from('listes')
        .select('proprietaire_id')
        .eq('id', suggestion['liste_id'] as String)
        .maybeSingle();
    final ownerId = list?['proprietaire_id'] as String?;
    if (ownerId == null || ownerId != userId) {
      throw Exception('Action non autorisee.');
    }

    await _client.from('suggestions').update({
      'statut': SuggestionStatus.refusee.dbValue,
      'motif_refus': motifRefus,
      'date_traitement': DateTime.now().toIso8601String(),
    }).eq('id', suggestionId);

    final suggesterId = suggestion['utilisateur_id'] as String?;
    final nomProduit = suggestion['nom_produit'] as String? ?? 'Produit';
    if (suggesterId != null && suggesterId.isNotEmpty) {
      await _client.from('notifications').insert({
        'utilisateur_id': suggesterId,
        'type': 'SUGGESTION',
        'message':
            'Votre suggestion "$nomProduit" a ete refusee. Motif : $motifRefus',
        'est_lue': false,
      });
    }

    await _invokePush({
      'action': 'suggestion_refused',
      'listId': suggestion['liste_id'] as String,
      'suggestionId': suggestionId,
    });
  }
}
