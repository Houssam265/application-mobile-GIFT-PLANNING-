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
    if (entries.isEmpty) return {};

    final now = DateTime.now();
    final limitDate = DateTime(now.year, now.month - 11, 1);
    
    // Start from the oldest between limitDate and first entry
    var current = entries.first.key.isBefore(limitDate) ? limitDate : entries.first.key; 
    
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
      final startOfWeek = DateTime(d.year, d.month, d.day - diff);
      map[startOfWeek] = (map[startOfWeek] ?? 0) + 1;
    }
    
    final entries = map.entries.toList()..sort((a,b) => a.key.compareTo(b.key));
    if (entries.isEmpty) return {};

    final now = DateTime.now();
    final diffNow = now.weekday - 1;
    final currentWeek = DateTime(now.year, now.month, now.day - diffNow);
    
    final limitWeek = DateTime(currentWeek.year, currentWeek.month, currentWeek.day - (7 * 11));
    var start = entries.first.key.isBefore(limitWeek) ? limitWeek : entries.first.key;

    final filled = <DateTime, int>{};
    var current = start;
    while(current.isBefore(currentWeek) || current.isAtSameMomentAs(currentWeek)) {
      filled[current] = map[current] ?? 0;
      current = DateTime(current.year, current.month, current.day + 7);
    }
    return filled;
  }
}
