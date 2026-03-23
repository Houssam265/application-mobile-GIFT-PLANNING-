import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/admin_user_model.dart';

class AdminUserRepository {
  final SupabaseClient _supabase;

  AdminUserRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<List<AdminUserModel>> fetchUsers(String query) async {
    var request = _supabase.from('utilisateurs').select('*');

    if (query.isNotEmpty) {
      request = request.or('nom.ilike.%$query%,email.ilike.%$query%');
    }

    final response = await request.order('date_inscription', ascending: false);

    return (response as List<dynamic>)
        .map((e) => AdminUserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateUserStatus(String userId, bool estSuspendu) async {
    await _supabase.rpc('admin_suspend_user', params: {
      'target_user_id': userId,
      'is_suspended': estSuspendu,
    });
  }
}
