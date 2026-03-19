enum ProfileStatus { initial, loading, success, error }

class ProfileState {
  final ProfileStatus status;
  final String? errorMessage;
  final String? avatarUrl;
  final String? displayName;

  const ProfileState({
    this.status = ProfileStatus.initial,
    this.errorMessage,
    this.avatarUrl,
    this.displayName,
  });

  ProfileState copyWith({
    ProfileStatus? status,
    String? errorMessage,
    String? avatarUrl,
    String? displayName,
  }) {
    return ProfileState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      displayName: displayName ?? this.displayName,
    );
  }
}
