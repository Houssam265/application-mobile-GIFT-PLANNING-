import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/admin_list_model.dart';

class AdminListRepository {
  final SupabaseClient _supabase;

  AdminListRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<List<AdminListModel>> fetchLists({required String query, required String filterStatut}) async {
    var request = _supabase
        .from('listes')
        .select('*, utilisateurs(nom, email)');

    if (filterStatut != 'TOUTES') {
      request = request.eq('statut', filterStatut);
    }

    if (query.isNotEmpty) {
      request = request.or('titre.ilike.%$query%,nom_evenement.ilike.%$query%');
    }

    final response = await request.order('date_creation', ascending: false);

    return (response as List<dynamic>)
        .map((e) => AdminListModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateListStatus(String listId, String newStatus) async {
    await _supabase.rpc('admin_update_list_status', params: {
      'target_list_id': listId,
      'new_status': newStatus,
    });
  }

  Future<void> deleteList(String listId) async {
    await _supabase.rpc('admin_delete_list', params: {
      'target_list_id': listId,
    });
  }
}
