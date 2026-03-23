import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../products/domain/product_model.dart';
import '../data/suggestion_repository.dart';
import 'suggestion_model.dart';

final suggestionRepositoryProvider = Provider<SuggestionRepository>(
  (_) => SuggestionRepository(),
);

enum SuggestionFormStatus { idle, loading, success, error }

class SuggestionState {
  const SuggestionState({
    this.status = SuggestionFormStatus.idle,
    this.suggestion,
    this.suggestions = const [],
    this.errorMessage,
  });

  final SuggestionFormStatus status;
  final SuggestionModel? suggestion;
  final List<SuggestionModel> suggestions;
  final String? errorMessage;

  SuggestionState copyWith({
    SuggestionFormStatus? status,
    SuggestionModel? suggestion,
    List<SuggestionModel>? suggestions,
    String? errorMessage,
  }) {
    return SuggestionState(
      status: status ?? this.status,
      suggestion: suggestion ?? this.suggestion,
      suggestions: suggestions ?? this.suggestions,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class SuggestionNotifier extends StateNotifier<SuggestionState> {
  SuggestionNotifier(this._repository) : super(const SuggestionState());

  final SuggestionRepository _repository;

  Future<void> submitSuggestion({
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
    state = state.copyWith(status: SuggestionFormStatus.loading);
    try {
      final suggestion = await _repository.submitSuggestion(
        listeId: listeId,
        userId: userId,
        nomProduit: nomProduit,
        description: description,
        prixCible: prixCible,
        imageBytes: imageBytes,
        imageFileName: imageFileName,
        lienUrl: lienUrl,
        categorie: categorie,
      );
      state = state.copyWith(
        status: SuggestionFormStatus.success,
        suggestion: suggestion,
      );
    } catch (e) {
      state = state.copyWith(
        status: SuggestionFormStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadSuggestions(String listeId) async {
    state = state.copyWith(status: SuggestionFormStatus.loading);
    try {
      final suggestions = await _repository.getSuggestionsForList(listeId);
      state = state.copyWith(
        status: SuggestionFormStatus.success,
        suggestions: suggestions,
      );
    } catch (e) {
      state = state.copyWith(
        status: SuggestionFormStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> validateSuggestion({
    required String suggestionId,
    required String listeId,
  }) async {
    state = state.copyWith(status: SuggestionFormStatus.loading);
    try {
      await _repository.validateSuggestion(
        suggestionId: suggestionId,
        listeId: listeId,
      );
      await loadSuggestions(listeId);
    } catch (e) {
      state = state.copyWith(
        status: SuggestionFormStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> refuseSuggestion({
    required String suggestionId,
    required String userId,
    required String motifRefus,
    required String listeId,
  }) async {
    state = state.copyWith(status: SuggestionFormStatus.loading);
    try {
      await _repository.refuseSuggestion(
        suggestionId: suggestionId,
        userId: userId,
        motifRefus: motifRefus,
      );
      await loadSuggestions(listeId);
    } catch (e) {
      state = state.copyWith(
        status: SuggestionFormStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() => state = const SuggestionState();
}

final suggestionProvider =
    StateNotifierProvider.autoDispose<SuggestionNotifier, SuggestionState>(
  (ref) => SuggestionNotifier(ref.watch(suggestionRepositoryProvider)),
);
