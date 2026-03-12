import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

enum ListVisibility {
  public,
  private,
  anonymous,
}

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
      // Assumption: un bucket Supabase nommé "list-covers" existe.
      final safeFileName = couvertureFileName.replaceAll(' ', '_');
      final path = 'covers/${user.id}/${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

      await _client.storage.from('list-covers').uploadBinary(
            path,
            couvertureBytes,
            fileOptions: const FileOptions(
              upsert: false,
              // ContentType générique, Supabase peut le déduire plus finement si besoin
              contentType: 'image/jpeg',
            ),
          );

      coverUrl = _client.storage.from('list-covers').getPublicUrl(path);
    }

    // 2) Génération d'un code/slug unique
    final codePartage = _generateCodePartage();
    final slug = _generateSlug();

    final dateEvenementIso = dateEvenement.toIso8601String().split('T').first;

    final payload = {
      'titre': titre,
      'description': description,
      'nom_evenement': nomEvenement,
      'date_evenement': dateEvenementIso,
      'photo_couverture_url': coverUrl,
      'lien_partage': 'giftplan.app/liste/$slug',
      'code_partage': codePartage,
      'visibilite_contributions': visibility.dbValue,
      'proprietaire_id': user.id,
    };

    final response = await _client.from('listes').insert(payload).select('id').single();

    return response['id'] as String;
  }

  /// Récupère les informations d'une liste par son id.
  Future<Map<String, dynamic>> getListById(String id) async {
    final data = await _client.from('listes').select().eq('id', id).single();

    return data as Map<String, dynamic>;
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
      final safeFileName = couvertureFileName.replaceAll(' ', '_');
      final path = 'covers/${user.id}/${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

      await _client.storage.from('list-covers').uploadBinary(
            path,
            couvertureBytes,
            fileOptions: const FileOptions(
              upsert: false,
              contentType: 'image/jpeg',
            ),
          );

      coverUrl = _client.storage.from('list-covers').getPublicUrl(path);
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

  String _generateCodePartage() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String _generateSlug() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
