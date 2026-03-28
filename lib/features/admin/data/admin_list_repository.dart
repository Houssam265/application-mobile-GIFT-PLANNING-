import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/admin_list_model.dart';

class AdminListRepository {
  final SupabaseClient _supabase;

  AdminListRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<List<AdminListModel>> fetchLists({
    required String query,
    required String filterStatut,
  }) async {
    // We fetch with users join to have owner info
    var request = _supabase
        .from('listes')
        .select('*, utilisateurs(nom, email)');

    if (filterStatut != 'TOUTES') {
      request = request.eq('statut', filterStatut);
    }

    // Since we want a robust OR across main table and joined table, 
    // and given we aren't using pagination yet, we fetch all (filtered by status)
    // and apply the search filter in memory. This is the most reliable way 
    // to do cross-table 'OR' filtering without building specialized database views.
    final response = await request.order('date_creation', ascending: false);

    List<AdminListModel> lists = (response as List<dynamic>)
        .map((e) => AdminListModel.fromJson(e as Map<String, dynamic>))
        .toList();

    if (query.isNotEmpty) {
      final q = query.toLowerCase().trim();
      lists = lists.where((l) {
        return l.titre.toLowerCase().contains(q) ||
               l.nomEvenement.toLowerCase().contains(q) ||
               l.proprietaireNom.toLowerCase().contains(q) ||
               l.proprietaireEmail.toLowerCase().contains(q) ||
               l.proprietaireId.toLowerCase() == q ||
               l.id.toLowerCase() == q;
      }).toList();
    }

    return lists;
  }

  Future<Map<String, int>> fetchListStats() async {
    final response = await _supabase.from('listes').select('statut');
    final lists = response as List<dynamic>;

    final total = lists.length;
    final active = lists.where((l) => l['statut'] == 'ACTIVE').length;
    final archived = total - active;

    return {
      'total': total,
      'active': active,
      'archived': archived,
    };
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
