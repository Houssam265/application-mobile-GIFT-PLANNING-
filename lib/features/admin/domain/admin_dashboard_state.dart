class AdminDashboardState {
  final Map<DateTime, int> usersPerWeek;
  final Map<DateTime, int> listsPerMonth;
  final bool isLoading;
  final String? error;

  AdminDashboardState({
    required this.usersPerWeek,
    required this.listsPerMonth,
    this.isLoading = false,
    this.error,
  });

  factory AdminDashboardState.initial() => AdminDashboardState(
    usersPerWeek: {},
    listsPerMonth: {},
    isLoading: true,
  );

  AdminDashboardState copyWith({
    Map<DateTime, int>? usersPerWeek,
    Map<DateTime, int>? listsPerMonth,
    bool? isLoading,
    String? error,
  }) {
    return AdminDashboardState(
      usersPerWeek: usersPerWeek ?? this.usersPerWeek,
      listsPerMonth: listsPerMonth ?? this.listsPerMonth,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}
