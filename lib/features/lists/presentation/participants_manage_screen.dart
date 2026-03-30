import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/notifications/notification_insert.dart';
import '../../../core/widgets/loading_widget.dart';

class ParticipantsManageScreen extends StatefulWidget {
  final String listId;

  const ParticipantsManageScreen({super.key, required this.listId});

  @override
  State<ParticipantsManageScreen> createState() => _ParticipantsManageScreenState();
}

class _ParticipantsManageScreenState extends State<ParticipantsManageScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingMembers = [];
  List<Map<String, dynamic>> _activeMembers = [];



  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final res = await Supabase.instance.client
          .from('participations')
          .select('*, utilisateurs(id, nom, email, photo_profil_url)')
          .eq('liste_id', widget.listId)
          .neq('role', 'PROPRIETAIRE')
          .order('date_adhesion', ascending: false);
          
      final data = List<Map<String, dynamic>>.from(res);
      
      setState(() {
        _pendingMembers = data.where((m) => m['role'] == 'EN_ATTENTE').toList();
        _activeMembers = data.where((m) => m['role'] == 'INVITE').toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _acceptMember(String participationId) async {
    try {
      // 1. Direct DB update (garantit le fonctionnement de l'appli)
      await Supabase.instance.client
          .from('participations')
          .update({'role': 'INVITE'})
          .eq('id', participationId);

      try {
        final target = await Supabase.instance.client
            .from('participations')
            .select('utilisateur_id')
            .eq('id', participationId)
            .maybeSingle();
        final targetUserId = target?['utilisateur_id'] as String?;
        final listRow = await Supabase.instance.client
            .from('listes')
            .select('titre')
            .eq('id', widget.listId)
            .maybeSingle();
        final listTitle = listRow?['titre'] as String? ?? 'Liste';
        if (targetUserId != null && targetUserId.isNotEmpty) {
          await insertInAppNotification(
            userId: targetUserId,
            type: 'ADHESION',
            message: 'Votre demande pour "$listTitle" a ete acceptee.',
            action: 'join_accepted',
            listId: widget.listId,
            sentAt: DateTime.now(),
          );
        }
      } catch (_) {}

      // 2. Notif Push
      try {
        try {
          await Supabase.instance.client.auth.refreshSession();
        } catch (_) {}
        await Supabase.instance.client.functions.invoke(
          'participant-notifications',
          body: {
            'action': 'join_accepted',
            'listId': widget.listId,
            'participationId': participationId,
          },
        );
      } catch (e) {
        debugPrint('Push ignorée (accept): $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Participant accepté.')),
      );
      _fetchMembers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _refuseMember(String participationId) async {
    try {
      String? targetUserId;
      String listTitle = 'Liste';
      try {
        final target = await Supabase.instance.client
            .from('participations')
            .select('utilisateur_id, liste_id')
            .eq('id', participationId)
            .maybeSingle();
        targetUserId = target?['utilisateur_id'] as String?;
        final listRow = await Supabase.instance.client
            .from('listes')
            .select('titre')
            .eq('id', widget.listId)
            .maybeSingle();
        listTitle = listRow?['titre'] as String? ?? 'Liste';
      } catch (_) {}

      // 1. Direct DB suppression
      await Supabase.instance.client
          .from('participations')
          .delete()
          .eq('id', participationId);

      try {
        if (targetUserId != null && targetUserId.isNotEmpty) {
          await insertInAppNotification(
            userId: targetUserId,
            type: 'ADHESION',
            message: 'Votre demande pour "$listTitle" a ete refusee.',
            action: 'join_refused',
            listId: widget.listId,
            sentAt: DateTime.now(),
          );
        }
      } catch (_) {}

      // 2. Notif Push
      try {
        try {
          await Supabase.instance.client.auth.refreshSession();
        } catch (_) {}
        await Supabase.instance.client.functions.invoke(
          'participant-notifications',
          body: {
            'action': 'join_refused',
            'listId': widget.listId,
            'participationId': participationId,
          },
        );
      } catch (e) {
        debugPrint('Push ignorée (refuse): $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demande refusée.')),
      );
      _fetchMembers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _removeMember(String participationId, String userName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer le participant'),
        content: Text('Êtes-vous sûr de vouloir retirer $userName de cette liste ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('participations')
            .delete()
            .eq('id', participationId);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Participant retiré.')),
        );
        _fetchMembers();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Widget _buildUserAvatar(Map<String, dynamic> user, double size) {
    final photoUrl = user['photo_profil_url'] as String?;
    final nom = user['nom'] as String? ?? '?';
    
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFF2E86AB).withOpacity(0.2),
      child: Text(
        nom.isNotEmpty ? nom[0].toUpperCase() : '?',
        style: TextStyle(
          color: const Color(0xFF1E3A5F),
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
        ),
      ),
    );
  }

  Widget _buildPendingSection() {
    if (_pendingMembers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('Aucune demande en attente', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _pendingMembers.length,
      itemBuilder: (context, index) {
        final p = _pendingMembers[index];
        final participationId = p['id'];
        final userRaw = p['utilisateurs'] ?? p['utilisateur'];
        Map<String, dynamic> user = {};
        if (userRaw != null) {
          user = userRaw is Map<String, dynamic> 
            ? userRaw 
            : (userRaw is List && userRaw.isNotEmpty ? userRaw[0] as Map<String, dynamic> : <String, dynamic>{});
        }
        final String nom = user['nom']?.toString() ?? 'Utilisateur inconnu';
        final String email = user['email']?.toString() ?? '';
        
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.orange.shade200, width: 1),
          ),
          child: ListTile(
            leading: _buildUserAvatar(user, 40),
            title: Text(nom, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(email),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  tooltip: 'Accepter',
                  onPressed: () => _acceptMember(participationId),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.redAccent),
                  tooltip: 'Refuser',
                  onPressed: () => _refuseMember(participationId),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveSection() {
    if (_activeMembers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('Aucun participant actif', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _activeMembers.length,
      itemBuilder: (context, index) {
        final p = _activeMembers[index];
        final participationId = p['id'];
        final userRaw = p['utilisateurs'] ?? p['utilisateur'];
        Map<String, dynamic> user = {};
        if (userRaw != null) {
          user = userRaw is Map<String, dynamic> 
            ? userRaw 
            : (userRaw is List && userRaw.isNotEmpty ? userRaw[0] as Map<String, dynamic> : <String, dynamic>{});
        }
        final String nom = user['nom']?.toString() ?? 'Utilisateur inconnu';
        final String email = user['email']?.toString() ?? '';
        
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: _buildUserAvatar(user, 40),
            title: Text(nom, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(email),
            trailing: IconButton(
              icon: Icon(Icons.person_remove, color: Colors.grey.shade600),
              tooltip: 'Retirer de la liste',
              onPressed: () => _removeMember(participationId, nom),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: LoadingWidget(message: 'Chargement des participants...')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        title: const Text('Gérer les participants', style: TextStyle(color: Color(0xFF1E3A5F), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMembers,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                const Icon(Icons.pending_actions_rounded, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Demandes en attente (${_pendingMembers.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildPendingSection(),
            
            const SizedBox(height: 32),
            
            Row(
              children: [
                const Icon(Icons.people_alt_rounded, color: Color(0xFF2E86AB)),
                const SizedBox(width: 8),
                Text(
                  'Membres actifs (${_activeMembers.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildActiveSection(),
            
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}


