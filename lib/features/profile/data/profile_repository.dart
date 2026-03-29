import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  final SupabaseClient _supabase;

  ProfileRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;

  Future<Map<String, dynamic>?> fetchUserProfile(String userId) async {
    try {
      return await _supabase
          .from('utilisateurs')
          .select()
          .eq('id', userId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  Future<void> updateDisplayName(String name) async {
    final user = currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');
    
    // Mettre à jour la vraie table de base de données
    await _supabase.from('utilisateurs').update({'nom': name}).eq('id', user.id);
    
    // Update Auth pour la compatibilité
    await _supabase.auth.updateUser(
      UserAttributes(data: {'nom': name, 'display_name': name}),
    );
  }

  Future<String> uploadAvatar(Uint8List imageBytes, String userId) async {
    // Generate unique name
    final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    // Upload standard file to storage
    await _supabase.storage.from('avatars').uploadBinary(
          fileName,
          imageBytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );
        
    // Generate public URL
    final publicUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);
    
    // Update the custom table to prevent Google overriding auth metadata
    await _supabase.from('utilisateurs').update({'photo_profil_url': publicUrl}).eq('id', userId);
    
    // Update user attribute as fallback
    await _supabase.auth.updateUser(
      UserAttributes(data: {'avatar_url': publicUrl}),
    );
    
    return publicUrl;
  }

  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    // Appel à une fonction RPC Supabase (Backend)
    // qui s'occupe de supprimer l'utilisateur et d'anonymiser ou effacer en cascade
    await _supabase.rpc('delete_user_account');
    
    // Déconnexion forcée
    await _supabase.auth.signOut();
  }
}
