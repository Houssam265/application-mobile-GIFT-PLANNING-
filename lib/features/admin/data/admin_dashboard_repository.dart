import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardRepository {
  final SupabaseClient _supabase;

  AdminDashboardRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<List<DateTime>> fetchUserRegistrations() async {
    final response = await _supabase.from('utilisateurs').select('date_inscription');
    return (response as List).map((row) {
      final dateStr = row['date_inscription'] as String?;
      return dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();
    }).toList();
  }

  Future<List<DateTime>> fetchListCreations() async {
    final response = await _supabase.from('listes').select('date_creation');
    return (response as List).map((row) {
      final dateStr = row['date_creation'] as String?;
      return dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();
    }).toList();
  }
}
