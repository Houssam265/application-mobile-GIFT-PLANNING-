import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_links.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/services/storage_service.dart';

enum ListVisibility { public, private, anonymous }

extension ListVisibilityDbExtension on ListVisibility {
  String get dbValue {
    switch (this) {
      case ListVisibility.public:
        return 'PUBLIC';
      case ListVisibility.private:
        return 'PRIVE';
      case ListVisibility.anonymous:
        return 'ANONYME';
    }
  }
}

ListVisibility visibilityFromDb(String value) {
  switch (value.toUpperCase()) {
    case 'PUBLIC':
      return ListVisibility.public;
    case 'PRIVE':
      return ListVisibility.private;
    case 'ANONYME':
      return ListVisibility.anonymous;
    default:
      return ListVisibility.public;
  }
}

class ListRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final _storage = StorageService();

  /// Crée une liste de souhaits dans la table `listes`.
  ///
  /// Retourne l'id de la liste créée.
  Future<String> createList({
    required String titre,
    String? description,
    required String nomEvenement,
    required DateTime dateEvenement,
    Uint8List? couvertureBytes,
    String? couvertureFileName,
    required ListVisibility visibility,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    // 1) Upload éventuel de la photo de couverture dans le bucket Storage
    String? coverUrl;
    if (couvertureBytes != null && couvertureFileName != null) {
      coverUrl = await _storage.upload(
        bucket: StorageBucket.listCovers,
        bytes: couvertureBytes,
        fileName: couvertureFileName,
        folder: user.id,
      );
    }

    // 2) Génération d'un code/slug unique
    final codePartage = _generateCodePartage();

    final dateEvenementIso = dateEvenement.toIso8601String().split('T').first;

    final payload = {
      'titre': titre,
      'description': description,
      'nom_evenement': nomEvenement,
      'date_evenement': dateEvenementIso,
      'photo_couverture_url': coverUrl,
      'lien_partage': AppLinks.joinUrl(codePartage),
      'code_partage': codePartage,
      'visibilite_contributions': visibility.dbValue,
      'proprietaire_id': user.id,
    };

    final response = await _client
        .from('listes')
        .insert(payload)
        .select('id')
        .single();

    return response['id'] as String;
  }

  /// Récupère les informations d'une liste par son id.
  Future<Map<String, dynamic>> getListById(String id) async {
    final data = await _client.from('listes').select().eq('id', id).single();

    return data as Map<String, dynamic>;
  }

  /// Récupère les données minimales pour l'aperçu public via `code_partage`.
  ///
  /// Retourne: id, titre, nom_evenement, date_evenement, photo_couverture_url,
  /// code_partage, products_count
  Future<Map<String, dynamic>> getJoinPreviewByCode(String code) async {
    final listData = await _client
        .from('listes')
        .select(
          'id, titre, nom_evenement, date_evenement, photo_couverture_url, code_partage',
        )
        .eq('code_partage', code)
        .maybeSingle();

    if (listData == null) {
      throw Exception('Aucune liste trouvée pour ce lien.');
    }

    final listId = listData['id'] as String;
    final products = await _client
        .from('produits')
        .select('id')
        .eq('liste_id', listId);

    return {
      ...listData,
      'products_count': (products as List).length,
    };
  }

  /// Met à jour une liste existante.
  Future<void> updateList({
    required String id,
    required String titre,
    String? description,
    required String nomEvenement,
    required DateTime dateEvenement,
    Uint8List? couvertureBytes,
    String? couvertureFileName,
    required ListVisibility visibility,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    String? coverUrl;
    if (couvertureBytes != null && couvertureFileName != null) {
      coverUrl = await _storage.upload(
        bucket: StorageBucket.listCovers,
        bytes: couvertureBytes,
        fileName: couvertureFileName,
        folder: user.id,
      );
    }

    final dateEvenementIso = dateEvenement.toIso8601String().split('T').first;

    final payload = <String, dynamic>{
      'titre': titre,
      'description': description,
      'nom_evenement': nomEvenement,
      'date_evenement': dateEvenementIso,
      'visibilite_contributions': visibility.dbValue,
      'date_modification': DateTime.now().toIso8601String(),
    };

    if (coverUrl != null) {
      payload['photo_couverture_url'] = coverUrl;
    }

    await _client.from('listes').update(payload).eq('id', id);
  }

  /// Archive manuellement une liste (propriétaire uniquement).
  Future<void> archiveList(String id) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final nowIso = DateTime.now().toIso8601String();

    await _client
        .from('listes')
        .update({
          'statut': 'ARCHIVEE',
          'date_archivage': nowIso,
          'date_modification': nowIso,
        })
        .eq('id', id)
        .eq('proprietaire_id', user.id);

    try {
      try {
        await Supabase.instance.client.auth.refreshSession();
      } catch (_) {}
      
      await _client.functions.invoke(
        'participant-notifications',
        body: {
          'action': 'list_archived_notify',
          'listId': id,
        },
      );
    } catch (e) {
      debugPrint('list_archived_notify push ignorée: $e');
    }
  }

  /// Réactive une liste archivée avec une nouvelle date d'événement.
  Future<void> reactivateList({
    required String id,
    required DateTime newEventDate,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final dateEvenementIso = newEventDate.toIso8601String().split('T').first;
    final nowIso = DateTime.now().toIso8601String();

    await _client
        .from('listes')
        .update({
          'statut': 'ACTIVE',
          'date_evenement': dateEvenementIso,
          'date_archivage': null,
          'date_modification': nowIso,
        })
        .eq('id', id)
        .eq('proprietaire_id', user.id);
  }

  /// Supprime définitivement une liste archivée (cascade sur produits, contributions, ...).
  Future<void> deleteArchivedList(String id) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    // 1. Fetch the list to check for a cover image
    final listData = await _client
        .from('listes')
        .select('photo_couverture_url')
        .eq('id', id)
        .eq('proprietaire_id', user.id)
        .eq('statut', 'ARCHIVEE')
        .maybeSingle();

    if (listData == null) return; // List not found or not archived

    // 2. Delete the cover image from storage if it exists
    final coverUrl = listData['photo_couverture_url'] as String?;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      try {
        final path = StorageService.pathFromUrl(
          coverUrl,
          StorageBucket.listCovers,
        );
        await _storage.delete(bucket: StorageBucket.listCovers, path: path);
      } catch (e) {
        // Log but don't block list deletion if storage deletion fails
        debugPrint('Failed to delete list cover image: $e');
      }
    }

    // 3. Delete the list row
    await _client
        .from('listes')
        .delete()
        .eq('id', id)
        .eq('proprietaire_id', user.id)
        .eq('statut', 'ARCHIVEE');
  }

  String _generateCodePartage() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Demande à rejoindre une liste.
  ///
  /// Retourne `PENDING` si une demande est créée/encore en attente,
  /// `ALREADY_MEMBER` si l'utilisateur est déjà membre.
  Future<String> joinList(String id) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    // Vérifier si déjà membre
    final existing = await _client
        .from('participations')
        .select('id, role')
        .eq('liste_id', id)
        .eq('utilisateur_id', user.id)
        .maybeSingle();

    if (existing != null) {
      final role = existing['role'] as String? ?? '';
      if (role == 'INVITE' || role == 'PROPRIETAIRE') {
        return 'ALREADY_MEMBER';
      }
      if (role == 'EN_ATTENTE') {
        return 'PENDING';
      }
    }

    // 1. Créer la demande de participation dans la base de données (100% fiable)
    await _client.from('participations').upsert({
      'liste_id': id,
      'utilisateur_id': user.id,
      'role': 'EN_ATTENTE',
    }, onConflict: 'liste_id,utilisateur_id');

    try {
      final listRow = await _client
          .from('listes')
          .select('proprietaire_id, titre')
          .eq('id', id)
          .maybeSingle();
      final ownerId = listRow?['proprietaire_id'] as String?;
      final listTitle = listRow?['titre'] as String? ?? 'Liste';
      if (ownerId != null && ownerId.isNotEmpty) {
        await _client.from('notifications').insert({
          'utilisateur_id': ownerId,
          'type': 'ADHESION',
          'message': 'Nouvelle demande pour « $listTitle ».',
          'est_lue': false,
          'date_envoi': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}

    // 2. Envoyer la notification push
    try {
      try {
        await Supabase.instance.client.auth.refreshSession();
      } catch (_) {}
      final token = Supabase.instance.client.auth.currentSession?.accessToken ?? '';

      await _client.functions.invoke(
        'participant-notifications',
        body: {
          'action': 'join_request',
          'listId': id,
        },
      );
    } catch (e) {
      debugPrint('join_request push ignorée: $e');
    }

    return 'PENDING';
  }
}
