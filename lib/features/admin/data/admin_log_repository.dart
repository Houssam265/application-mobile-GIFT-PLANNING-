import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/admin_log_model.dart';

class AdminLogRepository {
  final SupabaseClient _supabase;

  AdminLogRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<List<AdminLog>> fetchLogs({
    int limit = 20,
    int offset = 0,
    String? actionFilter,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = _supabase.from('admin_logs').select('*, utilisateurs(nom)');

    if (actionFilter != null && actionFilter.isNotEmpty) {
      query = query.eq('action', actionFilter);
    }

    if (startDate != null) {
      query = query.gte('created_at', startDate.toIso8601String());
    }

    if (endDate != null) {
      query = query.lte('created_at', endDate.toIso8601String());
    }

    final List<dynamic> response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
        
    return response.map((json) => AdminLog.fromJson(json)).toList();
  }
}
