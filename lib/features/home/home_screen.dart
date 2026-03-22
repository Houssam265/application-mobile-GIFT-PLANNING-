import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/router/app_router.dart';
import '../lists/presentation/join_list_entry_sheet.dart';
import '../profile/domain/profile_notifier.dart';
import 'widgets/dashboard_list_card.dart';

/// GP-17 — Tableau de bord personnel : onglets Mes listes / Listes rejointes / Archivées,
/// recherche plein texte sur titre, événement et description, accès rapide aux notifications non lues.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

bool _listMatchesSearch(Map<String, dynamic> list, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final parts = q.split(RegExp(r'\s+'));
  final titre = (list['titre'] ?? '').toString().toLowerCase();
  final nomEv = (list['nom_evenement'] ?? '').toString().toLowerCase();
  final desc = (list['description'] ?? '').toString().toLowerCase();
  final haystack = '$titre $nomEv $desc';
  return parts.every((p) => p.isEmpty || haystack.contains(p));
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _myLists = [];
  List<Map<String, dynamic>> _joinedLists = [];
  List<Map<String, dynamic>> _archivedLists = [];
  bool _loading = true;
  String _searchQuery = '';
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUnreadNotifications(String userId) async {
    try {
      final rows = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('utilisateur_id', userId)
          .eq('est_lue', false);
      if (mounted) {
        setState(() {
          _unreadNotifications = (rows as List).length;
        });
      }
    } catch (e) {
      debugPrint('Erreur compteur notifications: $e');
    }
  }

  Future<void> _fetchDashboardData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    await _fetchUnreadNotifications(user.id);

    try {
      final myListsData = await Supabase.instance.client
          .from('listes')
          .select('*, produits(id, statut_financement)')
          .eq('proprietaire_id', user.id)
          .eq('statut', 'ACTIVE')
          .order('date_creation', ascending: false);

      final joinedListsData = await Supabase.instance.client
          .from('listes')
          .select('*, produits(id, statut_financement), participations!inner(utilisateur_id)')
          .eq('participations.utilisateur_id', user.id)
          .neq('proprietaire_id', user.id)
          .eq('statut', 'ACTIVE')
          .order('date_creation', ascending: false);

      final myArchivedListsData = await Supabase.instance.client
          .from('listes')
          .select('*, produits(id, statut_financement)')
          .eq('proprietaire_id', user.id)
          .eq('statut', 'ARCHIVEE')
          .order('date_creation', ascending: false);

      final joinedArchivedListsData = await Supabase.instance.client
          .from('listes')
          .select('*, produits(id, statut_financement), participations!inner(utilisateur_id)')
          .eq('participations.utilisateur_id', user.id)
          .neq('proprietaire_id', user.id)
          .eq('statut', 'ARCHIVEE')
          .order('date_creation', ascending: false);

      final combinedArchived = [
        ...List<Map<String, dynamic>>.from(myArchivedListsData),
        ...List<Map<String, dynamic>>.from(joinedArchivedListsData),
      ];

      combinedArchived.sort((a, b) {
        final dateA = DateTime.tryParse(a['date_creation'] ?? '') ?? DateTime(2000);
        final dateB = DateTime.tryParse(b['date_creation'] ?? '') ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _myLists = List<Map<String, dynamic>>.from(myListsData);
          _joinedLists = List<Map<String, dynamic>>.from(joinedListsData);
          _archivedLists = combinedArchived;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
      debugPrint('Error fetching lists: $e');
    }
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> source) {
    return source.where((m) => _listMatchesSearch(m, _searchQuery)).toList();
  }

  Widget _buildListTab(List<Map<String, dynamic>> lists, {double bottomPadding = 24}) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2E86AB)));
    }
    final filtered = _filter(lists);
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.inbox_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Aucune liste ne correspond à « $_searchQuery ».'
                    : 'Aucune liste trouvée.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF2E86AB),
      onRefresh: _fetchDashboardData,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPadding),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          return DashboardListCard(listData: filtered[index]);
        },
      ),
    );
  }

  Future<void> _openNotifications() async {
    await context.pushNamed(AppRouteName.notificationsCenter);
    if (mounted) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) await _fetchUnreadNotifications(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        title: const Text(
          'Mon tableau de bord',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: _openNotifications,
            icon: Badge(
              isLabelVisible: _unreadNotifications > 0,
              label: Text(
                _unreadNotifications > 99 ? '99+' : '$_unreadNotifications',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              backgroundColor: const Color(0xFFDC2626),
              child: const Icon(Icons.notifications_outlined, color: Color(0xFF1E3A5F)),
            ),
          ),
          Consumer(
            builder: (context, ref, child) {
              final profileState = ref.watch(profileNotifierProvider);
              return GestureDetector(
                onTap: () => context.pushNamed(AppRouteName.profile),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: profileState.avatarUrl != null && profileState.avatarUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(profileState.avatarUrl!)
                        : null,
                    child: profileState.avatarUrl == null || profileState.avatarUrl!.isEmpty
                        ? const Icon(Icons.person_rounded, color: Colors.grey, size: 20)
                        : null,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.grey),
            onPressed: () => Supabase.instance.client.auth.signOut(),
            tooltip: 'Se déconnecter',
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2E86AB),
          unselectedLabelColor: Colors.grey.shade500,
          indicatorColor: const Color(0xFF2E86AB),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: 'Mes listes'),
            Tab(text: 'Listes rejointes'),
            Tab(text: 'Archivées'),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.white,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Rechercher une liste (titre, événement, description)…',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade600),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          tooltip: 'Effacer',
                          icon: Icon(Icons.clear_rounded, color: Colors.grey.shade600),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF4F7F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildListTab(_myLists, bottomPadding: 88),
                _buildListTab(_joinedLists, bottomPadding: 88),
                _buildListTab(_archivedLists),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              heroTag: 'fab_dashboard_create_list',
              onPressed: () => context.pushNamed(AppRouteName.listCreate),
              backgroundColor: const Color(0xFF2E86AB),
              foregroundColor: Colors.white,
              tooltip: 'Créer une liste',
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : _tabController.index == 1
              ? FloatingActionButton(
                  heroTag: 'fab_dashboard_join_list',
                  onPressed: () => showJoinListEntrySheet(context),
                  backgroundColor: const Color(0xFF2E86AB),
                  foregroundColor: Colors.white,
                  tooltip: 'Rejoindre une liste (QR ou code)',
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.group_add_rounded, size: 28),
                )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
