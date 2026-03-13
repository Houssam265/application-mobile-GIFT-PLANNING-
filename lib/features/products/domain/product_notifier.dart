import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/product_repository.dart';
import '../domain/product_model.dart';

// ── Repository provider ───────────────────────────────────────────────────────

final productRepositoryProvider = Provider<ProductRepository>(
  (_) => ProductRepository(),
);

// ── Shared state ──────────────────────────────────────────────────────────────

enum ProductFormStatus { idle, loading, success, error }

class ProductFormState {
  const ProductFormState({
    this.status = ProductFormStatus.idle,
    this.product,
    this.errorMessage,
  });

  final ProductFormStatus status;
  final ProductModel? product;
  final String? errorMessage;

  ProductFormState copyWith({
    ProductFormStatus? status,
    ProductModel? product,
    String? errorMessage,
  }) {
    return ProductFormState(
      status: status ?? this.status,
      product: product ?? this.product,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class ProductFormNotifier extends StateNotifier<ProductFormState> {
  ProductFormNotifier(this._repository) : super(const ProductFormState());

  final ProductRepository _repository;

  Future<void> addProduct({
    required String listeId,
    required String nom,
    String? description,
    required double prixCible,
    Uint8List? imageBytes,
    String? imageFileName,
    String? lienUrl,
    ProductCategorie? categorie,
  }) async {
    state = state.copyWith(status: ProductFormStatus.loading);
    try {
      final product = await _repository.addProduct(
        listeId: listeId,
        nom: nom,
        description: description,
        prixCible: prixCible,
        imageBytes: imageBytes,
        imageFileName: imageFileName,
        lienUrl: lienUrl,
        categorie: categorie,
      );
      state = state.copyWith(status: ProductFormStatus.success, product: product);
    } catch (e) {
      state = state.copyWith(
          status: ProductFormStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> updateProduct({
    required String productId,
    required String nom,
    String? description,
    required double prixCible,
    Uint8List? imageBytes,
    String? imageFileName,
    String? lienUrl,
    ProductCategorie? categorie,
  }) async {
    state = state.copyWith(status: ProductFormStatus.loading);
    try {
      final product = await _repository.updateProduct(
        productId: productId,
        nom: nom,
        description: description,
        prixCible: prixCible,
        imageBytes: imageBytes,
        imageFileName: imageFileName,
        lienUrl: lienUrl,
        categorie: categorie,
      );
      state = state.copyWith(status: ProductFormStatus.success, product: product);
    } catch (e) {
      state = state.copyWith(
          status: ProductFormStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> deleteProduct(ProductModel product) async {
    state = state.copyWith(status: ProductFormStatus.loading);
    try {
      await _repository.deleteProduct(product);
      state = state.copyWith(status: ProductFormStatus.success);
    } catch (e) {
      state = state.copyWith(
          status: ProductFormStatus.error, errorMessage: e.toString());
    }
  }

  void reset() => state = const ProductFormState();
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Used by the add/edit product form.
final productFormProvider =
    StateNotifierProvider.autoDispose<ProductFormNotifier, ProductFormState>(
  (ref) => ProductFormNotifier(ref.watch(productRepositoryProvider)),
);

/// Kept for backward compatibility — resolves to the same notifier.
@Deprecated('Use productFormProvider')
final addProductProvider = productFormProvider;
