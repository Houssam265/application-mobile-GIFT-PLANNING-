import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/notifications/notification_insert.dart';
import '../../../core/services/storage_service.dart';
import '../domain/product_model.dart';

class ProductRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final _storage = StorageService();

  Future<ProductModel> addProduct({
    required String listeId,
    required String nom,
    String? description,
    required double prixCible,
    Uint8List? imageBytes,
    String? imageFileName,
    String? lienUrl,
    ProductCategorie? categorie,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connectÃ©.');

    final listRow = await _client
        .from('listes')
        .select('statut, titre, proprietaire_id')
        .eq('id', listeId)
        .maybeSingle();
    if (listRow == null) {
      throw Exception('Liste introuvable.');
    }
    final listStatus = (listRow['statut'] as String?) ?? 'ACTIVE';
    if (listStatus == 'ARCHIVEE') {
      throw Exception('Cette liste est archivÃ©e. Ajout de produit impossible.');
    }

    String? imageUrl;
    if (imageBytes != null && imageFileName != null) {
      imageUrl = await _storage.upload(
        bucket: StorageBucket.products,
        bytes: imageBytes,
        fileName: imageFileName,
        folder: user.id,
      );
    }

    final payload = <String, dynamic>{
      'liste_id': listeId,
      'nom': nom,
      'description': description,
      'prix_cible': prixCible,
      'image_url': imageUrl,
      'lien_url': lienUrl?.isNotEmpty == true ? lienUrl : null,
      'categorie': categorie?.dbValue,
      'statut_financement': StatutFinancement.nonFinance.dbValue,
    };

    final response = await _client
        .from('produits')
        .insert(payload)
        .select()
        .single();

    final product = ProductModel.fromMap(response);

    try {
      try {
        await Supabase.instance.client.auth.refreshSession();
      } catch (_) {}
      await _client.functions.invoke(
        'participant-notifications',
        body: {
          'action': 'product_added_notify_all',
          'listId': listeId,
          'productId': product.id,
          'excludeUserIds': [user.id],
        },
      );
    } catch (_) {
      final title = (listRow['titre'] as String?) ?? 'Liste';
      final parts = await _client
          .from('participations')
          .select('utilisateur_id')
          .eq('liste_id', listeId);
      final users = <String>{
        ...(parts as List)
            .map((e) => (e as Map<String, dynamic>)['utilisateur_id'] as String)
      };
      users.remove(user.id);
      final sentAt = DateTime.now();
      for (final uid in users) {
        await insertInAppNotification(
          client: _client,
          userId: uid,
          type: 'PRODUIT',
          message: 'Â« ${product.nom} Â» a Ã©tÃ© ajoutÃ© Ã  Â« $title Â».',
          action: 'product_added',
          listId: listeId,
          productId: product.id,
          sentAt: sentAt,
        );
      }
    }

    return product;
  }

  Future<ProductModel> updateProduct({
    required String productId,
    required String nom,
    String? description,
    required double prixCible,
    Uint8List? imageBytes,
    String? imageFileName,
    String? lienUrl,
    ProductCategorie? categorie,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connectÃ©.');

    String? imageUrl;
    if (imageBytes != null && imageFileName != null) {
      imageUrl = await _storage.upload(
        bucket: StorageBucket.products,
        bytes: imageBytes,
        fileName: imageFileName,
        folder: user.id,
      );
    }

    final payload = <String, dynamic>{
      'nom': nom,
      'description': description,
      'prix_cible': prixCible,
      'lien_url': lienUrl?.isNotEmpty == true ? lienUrl : null,
      'categorie': categorie?.dbValue,
      'date_modification': DateTime.now().toIso8601String(),
    };

    if (imageUrl != null) payload['image_url'] = imageUrl;

    final response = await _client
        .from('produits')
        .update(payload)
        .eq('id', productId)
        .select()
        .single();

    return ProductModel.fromMap(response);
  }

  Future<void> deleteProduct(ProductModel product) async {
    if (product.imageUrl != null) {
      final path = StorageService.pathFromUrl(
        product.imageUrl!,
        StorageBucket.products,
      );
      await _storage.delete(bucket: StorageBucket.products, path: path);
    }

    await _client.from('produits').delete().eq('id', product.id);
  }

  Future<List<ProductModel>> getProductsByList(String listeId) async {
    final response = await _client
        .from('produits')
        .select()
        .eq('liste_id', listeId)
        .order('date_creation', ascending: true);

    return (response as List)
        .map((e) => ProductModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<ProductModel> getProductById(String productId) async {
    final response = await _client
        .from('produits')
        .select()
        .eq('id', productId)
        .maybeSingle();

    if (response == null) {
      throw Exception('Produit introuvable.');
    }

    return ProductModel.fromMap(response);
  }
}
