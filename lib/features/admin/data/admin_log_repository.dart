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
    // ── 1. Base query: fetch logs + admin name ─────────────────────────────
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

    List<AdminLog> logs = response.map((json) => AdminLog.fromJson(json)).toList();

    // ── 2. Enrich USER targets (get email from utilisateurs) ───────────────
    final userLogs = logs.where((l) => l.targetType == 'USER').toList();
    if (userLogs.isNotEmpty) {
      final userIds = userLogs.map((l) => l.targetId).toSet().toList();
      final userRows = await _supabase
          .from('utilisateurs')
          .select('id, nom, email')
          .inFilter('id', userIds);

      final userMap = <String, Map<String, dynamic>>{
        for (final row in userRows as List<dynamic>)
          row['id'] as String: row as Map<String, dynamic>,
      };

      logs = logs.map((log) {
        if (log.targetType == 'USER' && userMap.containsKey(log.targetId)) {
          final data = userMap[log.targetId]!;
          return log.copyWithTarget(
            targetName: data['nom'] as String?,
            targetEmail: data['email'] as String?,
          );
        }
        return log;
      }).toList();
    }

    // ── 3. Enrich LIST targets (get list title + owner email) ──────────────
    final listLogs = logs.where((l) => l.targetType == 'LIST').toList();
    if (listLogs.isNotEmpty) {
      final listIds = listLogs.map((l) => l.targetId).toSet().toList();
      final listRows = await _supabase
          .from('listes')
          .select('id, titre, utilisateurs(email)')
          .inFilter('id', listIds);

      final listMap = <String, Map<String, dynamic>>{
        for (final row in listRows as List<dynamic>)
          row['id'] as String: row as Map<String, dynamic>,
      };

      logs = logs.map((log) {
        if (log.targetType == 'LIST' && listMap.containsKey(log.targetId)) {
          final data = listMap[log.targetId]!;
          final ownerEmail = data['utilisateurs']?['email'] as String?;
          return log.copyWithTarget(
            targetName: data['titre'] as String?,
            targetEmail: ownerEmail,
          );
        }
        return log;
      }).toList();
    }

    return logs;
  }
}
