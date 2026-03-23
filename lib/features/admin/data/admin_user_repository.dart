import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/admin_user_model.dart';

class AdminUserRepository {
  final SupabaseClient _supabase;

  AdminUserRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<List<AdminUserModel>> fetchUsers(String query, {bool? isSuspended}) async {
    var request = _supabase.from('utilisateurs').select('*');

    if (isSuspended != null) {
      request = request.eq('est_suspendu', isSuspended);
    }

    if (query.isNotEmpty) {
      request = request.or('nom.ilike.%$query%,email.ilike.%$query%');
    }

    final response = await request.order('date_inscription', ascending: false);

    return (response as List<dynamic>)
        .map((e) => AdminUserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, int>> fetchUserStats() async {
    final response = await _supabase.from('utilisateurs').select('est_suspendu');
    final users = response as List<dynamic>;
    
    final total = users.length;
    final suspended = users.where((u) => u['est_suspendu'] == true).length;
    final active = total - suspended;
    
    return {
      'total': total,
      'active': active,
      'suspended': suspended,
    };
  }

  Future<void> updateUserStatus(String userId, bool estSuspendu) async {
    await _supabase.rpc('admin_suspend_user', params: {
      'target_user_id': userId,
      'is_suspended': estSuspendu,
    });
  }
}
