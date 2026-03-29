import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/storage_service.dart';
import '../domain/product_model.dart';

class ProductRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final _storage = StorageService();

  /// Inserts a new product into the `produits` table.
  /// If [imageBytes] is provided, uploads it to the `products` bucket first.
  /// Returns the created [ProductModel].
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
    if (user == null) throw Exception('Utilisateur non connecté.');

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
      throw Exception('Cette liste est archivée. Ajout de produit impossible.');
    }

    // 1. Upload image if provided.
    String? imageUrl;
    if (imageBytes != null && imageFileName != null) {
      imageUrl = await _storage.upload(
        bucket: StorageBucket.products,
        bytes: imageBytes,
        fileName: imageFileName,
        folder: user.id,
      );
    }

    // 2. Build payload — statut_financement defaults to NON_FINANCE.
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

    // 3. Insert and return the full row.
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
      final ownerId = listRow['proprietaire_id'] as String?;
      if (ownerId != null && ownerId.isNotEmpty) {
        users.add(ownerId);
      }
      final nowIso = DateTime.now().toIso8601String();
      for (final uid in users) {
        await _client.from('notifications').insert({
          'utilisateur_id': uid,
          'type': 'SUGGESTION',
          'message': '« ${product.nom} » a été ajouté à « $title ».',
          'est_lue': false,
          'date_envoi': nowIso,
        });
      }
    }

    return product;
  }

  /// Updates an existing product. Only uploads a new image if [imageBytes] is provided.
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
    if (user == null) throw Exception('Utilisateur non connecté.');

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



  /// Deletes a product permanently and removes its image from storage if it exists.
  Future<void> deleteProduct(ProductModel product) async {
    // 1. Delete image from storage if it exists
    if (product.imageUrl != null) {
      final path = StorageService.pathFromUrl(
        product.imageUrl!,
        StorageBucket.products,
      );
      await _storage.delete(bucket: StorageBucket.products, path: path);
    }

    // 2. Delete row from database
    await _client.from('produits').delete().eq('id', product.id);
  }

  /// Fetches all products belonging to [listeId].
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

  /// Fetches a single product by its id.
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
