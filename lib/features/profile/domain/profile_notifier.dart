import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/profile_repository.dart';
import 'profile_state.dart';
import '../../../core/constants/supabase_constants.dart';

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
  RealtimeChannel? _profileChannel;

  ProfileNotifier(this._repository) : super(const ProfileState()) {
    _initData();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        state = const ProfileState();
        _profileChannel?.unsubscribe();
        _profileChannel = null;
      } else if (data.event == AuthChangeEvent.signedIn ||
                 data.event == AuthChangeEvent.userUpdated) {
        _initData();
      }
    });
  }

  @override
  void dispose() {
    _profileChannel?.unsubscribe();
    _authSub?.cancel();
    super.dispose();
  }

  void _subscribeToProfile(String userId) {
    if (_profileChannel != null) return; // Déjà abonné
    _profileChannel = Supabase.instance.client
        .channel('public:utilisateurs:profile_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'utilisateurs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            final newRow = payload.newRecord;
            final dbName = newRow['nom'] as String?;
            final dbAvatar = newRow['photo_profil_url'] as String?;
            final dbIsAdmin = newRow['est_administrateur'] as bool? ?? state.isAdmin;

            state = state.copyWith(
              displayName: (dbName != null && dbName.isNotEmpty) ? dbName : state.displayName,
              avatarUrl: (dbAvatar != null && dbAvatar.isNotEmpty) ? dbAvatar : state.avatarUrl,
              isAdmin: dbIsAdmin,
            );
          },
        )
        .subscribe();
  }

  Future<void> _initData() async {
    final user = _repository.currentUser;
    if (user != null) {
      state = state.copyWith(status: ProfileStatus.loading);
      _subscribeToProfile(user.id);
      try {
        final dbUser = await _repository.fetchUserProfile(user.id);
        if (dbUser != null) {
          final meta = user.userMetadata ?? {};
          final dbName = dbUser['nom'] as String?;
          final dbAvatar = dbUser['photo_profil_url'] as String?;
          final dbIsAdmin = dbUser['est_administrateur'] as bool? ?? false;

          final expectedRole = dbIsAdmin ? 'admin' : 'user';
          if (meta['role'] != expectedRole) {
            Supabase.instance.client.auth.updateUser(
              UserAttributes(data: {'role': expectedRole}),
            );
          }

          // Prefer the DB URL (already mirrored to Storage); fall back to OAuth metadata.
          final oauthAvatar = meta['avatar_url'] as String?;
          final resolvedAvatar = (dbAvatar != null && dbAvatar.isNotEmpty)
              ? dbAvatar
              : oauthAvatar;

          state = state.copyWith(
            status: ProfileStatus.success,
            displayName: (dbName != null && dbName.isNotEmpty)
                ? dbName
                : (meta['display_name'] as String? ?? meta['full_name'] as String?),
            avatarUrl: resolvedAvatar,
            isAdmin: dbIsAdmin,
          );

          // On Web, 3rd-party avatar URLs (Google, etc.) cause CORS/EncodingError.
          // Mirror once to our own Supabase Storage bucket.
          if (kIsWeb &&
              resolvedAvatar != null &&
              _isThirdPartyUrl(resolvedAvatar) &&
              (dbAvatar == null || dbAvatar.isEmpty)) {
            _mirrorThirdPartyAvatar(resolvedAvatar);
          }
        } else {
          final meta = user.userMetadata ?? {};
          final oauthAvatar = meta['avatar_url'] as String?;
          state = state.copyWith(
            status: ProfileStatus.success,
            displayName: meta['display_name'] as String? ?? meta['full_name'] as String?,
            avatarUrl: oauthAvatar,
            isAdmin: false,
          );
          if (kIsWeb && oauthAvatar != null && _isThirdPartyUrl(oauthAvatar)) {
            _mirrorThirdPartyAvatar(oauthAvatar);
          }
        }
      } catch (e) {
        final meta = user.userMetadata ?? {};
        state = state.copyWith(
          status: ProfileStatus.error,
          displayName: meta['display_name'] as String? ?? meta['full_name'] as String?,
          avatarUrl: meta['avatar_url'] as String?,
        );
      }
    }
  }

  /// Returns true when [url] belongs to a 3rd-party host (not our Supabase project).
  bool _isThirdPartyUrl(String url) {
    try {
      final host = Uri.parse(url).host;
      final ownHost = Uri.parse(SupabaseConstants.supabaseUrl).host;
      return host != ownHost;
    } catch (_) {
      return false;
    }
  }

  /// Calls the `mirror-avatar` edge function to re-host the OAuth avatar in our
  /// Supabase Storage bucket, then updates [state.avatarUrl] with the safe URL.
  Future<void> _mirrorThirdPartyAvatar(String thirdPartyUrl) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'mirror-avatar',
        body: {'avatarUrl': thirdPartyUrl},
      );
      final data = response.data as Map<String, dynamic>?;
      final publicUrl = data?['publicUrl'] as String?;
      if (publicUrl != null && publicUrl.isNotEmpty) {
        state = state.copyWith(avatarUrl: publicUrl);
      }
    } catch (e) {
      // Non-fatal: the app still works, avatar just won't render on Web.
      debugPrint('[ProfileNotifier] mirror-avatar failed: $e');
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

  Future<void> uploadAvatar(Uint8List imageBytes) async {
    state = state.copyWith(status: ProfileStatus.loading);
    try {
      final user = _repository.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');
      
      final publicUrl = await _repository.uploadAvatar(imageBytes, user.id);
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
