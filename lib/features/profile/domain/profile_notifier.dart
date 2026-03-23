import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/profile_repository.dart';
import 'profile_state.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

final profileNotifierProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier(ref.read(profileRepositoryProvider));
});

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileRepository _repository;
  StreamSubscription<AuthState>? _authSub;

  ProfileNotifier(this._repository) : super(const ProfileState()) {
    _initData();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        state = const ProfileState();
      } else if (data.event == AuthChangeEvent.signedIn ||
                 data.event == AuthChangeEvent.userUpdated) {
        _initData();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _initData() async {
    final user = _repository.currentUser;
    if (user != null) {
      try {
        final dbUser = await _repository.fetchUserProfile(user.id);
        if (dbUser != null) {
          final meta = user.userMetadata ?? {};
          final dbName = dbUser['nom'] as String?;
          final dbAvatar = dbUser['photo_profil_url'] as String?;
          final dbIsAdmin = dbUser['est_administrateur'] as bool? ?? false;

          state = state.copyWith(
            displayName: (dbName != null && dbName.isNotEmpty) 
                ? dbName 
                : (meta['display_name'] as String? ?? meta['full_name'] as String?),
            avatarUrl: (dbAvatar != null && dbAvatar.isNotEmpty) 
                ? dbAvatar 
                : meta['avatar_url'] as String?,
            isAdmin: dbIsAdmin,
          );
        } else {
          final meta = user.userMetadata ?? {};
          state = state.copyWith(
            displayName: meta['display_name'] as String? ?? meta['full_name'] as String?,
            avatarUrl: meta['avatar_url'] as String?,
            isAdmin: false,
          );
        }
      } catch (e) {
        final meta = user.userMetadata ?? {};
        state = state.copyWith(
          displayName: meta['display_name'] as String? ?? meta['full_name'] as String?,
          avatarUrl: meta['avatar_url'] as String?,
        );
      }
    }
  }

  Future<void> updateDisplayName(String newName) async {
    state = state.copyWith(status: ProfileStatus.loading);
    try {
      await _repository.updateDisplayName(newName);
      state = state.copyWith(status: ProfileStatus.success, displayName: newName);
    } catch (e) {
      state = state.copyWith(
        status: ProfileStatus.error,
        errorMessage: 'Échec de la mise à jour du nom: ${e.toString()}',
      );
    }
  }

  Future<void> uploadAvatar(File imageFile) async {
    state = state.copyWith(status: ProfileStatus.loading);
    try {
      final user = _repository.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');
      
      final publicUrl = await _repository.uploadAvatar(imageFile, user.id);
      state = state.copyWith(status: ProfileStatus.success, avatarUrl: publicUrl);
    } catch (e) {
      state = state.copyWith(
        status: ProfileStatus.error,
        errorMessage: 'Erreur lors de l\'upload de l\'image: ${e.toString()}',
      );
    }
  }

  Future<void> deleteAccount() async {
    state = state.copyWith(status: ProfileStatus.loading);
    try {
      await _repository.deleteAccount();
      state = state.copyWith(status: ProfileStatus.success);
    } catch (e) {
      state = state.copyWith(
        status: ProfileStatus.error,
        errorMessage: 'Erreur de suppression du compte: ${e.toString()}',
      );
    }
  }

  void resetStatus() {
    state = state.copyWith(status: ProfileStatus.initial, errorMessage: null);
  }
}
