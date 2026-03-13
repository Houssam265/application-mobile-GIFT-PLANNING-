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

    return ProductModel.fromMap(response as Map<String, dynamic>);
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
}
