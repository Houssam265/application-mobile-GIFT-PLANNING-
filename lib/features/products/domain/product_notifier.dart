import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/product_repository.dart';
import '../domain/product_model.dart';

// ── Repository provider ───────────────────────────────────────────────────────

final productRepositoryProvider = Provider<ProductRepository>(
  (_) => ProductRepository(),
);

// ── Add-product state ─────────────────────────────────────────────────────────

/// Sealed-like state for the add-product form submission.
enum AddProductStatus { idle, loading, success, error }

class AddProductState {
  const AddProductState({
    this.status = AddProductStatus.idle,
    this.createdProduct,
    this.errorMessage,
  });

  final AddProductStatus status;
  final ProductModel? createdProduct;
  final String? errorMessage;

  AddProductState copyWith({
    AddProductStatus? status,
    ProductModel? createdProduct,
    String? errorMessage,
  }) {
    return AddProductState(
      status: status ?? this.status,
      createdProduct: createdProduct ?? this.createdProduct,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AddProductNotifier extends StateNotifier<AddProductState> {
  AddProductNotifier(this._repository) : super(const AddProductState());

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
    state = state.copyWith(status: AddProductStatus.loading);

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

      state = state.copyWith(
        status: AddProductStatus.success,
        createdProduct: product,
      );
    } catch (e) {
      state = state.copyWith(
        status: AddProductStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() => state = const AddProductState();
}

// ── Provider ──────────────────────────────────────────────────────────────────

final addProductProvider =
    StateNotifierProvider.autoDispose<AddProductNotifier, AddProductState>(
  (ref) => AddProductNotifier(ref.watch(productRepositoryProvider)),
);
