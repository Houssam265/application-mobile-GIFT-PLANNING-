import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_dashboard_repository.dart';
import 'admin_dashboard_state.dart';

final adminDashboardRepositoryProvider = Provider((ref) => AdminDashboardRepository());

final adminDashboardNotifierProvider = StateNotifierProvider<AdminDashboardNotifier, AdminDashboardState>((ref) {
  return AdminDashboardNotifier(ref.watch(adminDashboardRepositoryProvider));
});

class AdminDashboardNotifier extends StateNotifier<AdminDashboardState> {
  final AdminDashboardRepository _repository;

  AdminDashboardNotifier(this._repository) : super(AdminDashboardState.initial()) {
    loadStats();
  }

  Future<void> loadStats() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final userDates = await _repository.fetchUserRegistrations();
      final listDates = await _repository.fetchListCreations();

      final usersPerWeek = _groupUsersByWeek(userDates);
      final listsPerMonth = _groupListsByMonth(listDates);

      state = state.copyWith(
        usersPerWeek: usersPerWeek,
        listsPerMonth: listsPerMonth,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Map<DateTime, int> _groupListsByMonth(List<DateTime> dates) {
    if (dates.isEmpty) return {};
    final Map<DateTime, int> map = {};
    for (final d in dates) {
      final startOfMonth = DateTime(d.year, d.month, 1);
      map[startOfMonth] = (map[startOfMonth] ?? 0) + 1;
    }
    
    final entries = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    
    final now = DateTime.now();
    var current = DateTime(now.year, now.month - 11, 1); // Max last 12 months
    if (entries.first.key.isAfter(current)) {
      current = entries.first.key; 
    }
    
    final end = DateTime(now.year, now.month, 1);
    final filled = <DateTime, int>{};
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      filled[current] = map[current] ?? 0;
      current = DateTime(current.year, current.month + 1, 1);
    }
    return filled;
  }

  Map<DateTime, int> _groupUsersByWeek(List<DateTime> dates) {
    if (dates.isEmpty) return {};
    final Map<DateTime, int> map = {};
    for (final d in dates) {
      final diff = d.weekday - 1;
      final startOfWeek = DateTime(d.year, d.month, d.day).subtract(Duration(days: diff));
      map[startOfWeek] = (map[startOfWeek] ?? 0) + 1;
    }
    
    final now = DateTime.now();
    final diff = now.weekday - 1;
    final currentWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: diff));
    
    // max last 12 weeks
    var start = currentWeek.subtract(const Duration(days: 7 * 11));
    final entries = map.entries.toList()..sort((a,b) => a.key.compareTo(b.key));
    if (entries.first.key.isAfter(start)) {
      start = entries.first.key;
    }

    final filled = <DateTime, int>{};
    var current = start;
    while(current.isBefore(currentWeek) || current.isAtSameMomentAs(currentWeek)) {
      filled[current] = map[current] ?? 0;
      current = current.add(const Duration(days: 7));
    }
    return filled;
  }
}
