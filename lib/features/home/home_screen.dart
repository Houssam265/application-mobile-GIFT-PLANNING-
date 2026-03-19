import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/router/app_router.dart';
import '../profile/domain/profile_notifier.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _myLists = [];
  List<Map<String, dynamic>> _joinedLists = [];
  List<Map<String, dynamic>> _archivedLists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchLists();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLists() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

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

      // Sort combined archived lists by date_creation
      combinedArchived.sort((a, b) {
        final dateA = DateTime.tryParse(a['date_creation'] ?? '') ?? DateTime(2000);
        final dateB = DateTime.tryParse(b['date_creation'] ?? '') ?? DateTime(2000);
        return dateB.compareTo(dateA); // descending
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

  Widget _buildListTab(List<Map<String, dynamic>> lists) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2E86AB)));
    }
    if (lists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Aucune liste trouvée.',
              style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF2E86AB),
      onRefresh: _fetchLists,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        itemCount: lists.length,
        itemBuilder: (context, index) {
          return _ListCard(listData: lists[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F))),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2E86AB).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.add_rounded, color: Color(0xFF2E86AB)),
              onPressed: () => context.pushNamed(AppRouteName.listCreate),
              tooltip: 'Créer une liste',
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
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2E86AB),
          unselectedLabelColor: Colors.grey.shade500,
          indicatorColor: const Color(0xFF2E86AB),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          tabs: const [
            Tab(text: 'Mes listes'),
            Tab(text: 'Rejointes'),
            Tab(text: 'Archivées'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildListTab(_myLists),
          _buildListTab(_joinedLists),
          _buildListTab(_archivedLists),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  final Map<String, dynamic> listData;

  const _ListCard({required this.listData});

  @override
  Widget build(BuildContext context) {
    final title = listData['titre'] ?? 'Liste';
    final eventName = listData['nom_evenement'] ?? 'Événement';
    final eventDateStr = listData['date_evenement'];
    final coverUrl = listData['photo_couverture_url'];
    final products = listData['produits'] as List<dynamic>? ?? [];
    
    DateTime? eventDate;
    if (eventDateStr != null) {
      eventDate = DateTime.tryParse(eventDateStr);
    }
    String formattedDate = '';
    int daysLeft = 0;
    if (eventDate != null) {
      formattedDate = _formatDate(eventDate);
      final now = DateTime.now();
      daysLeft = eventDate.difference(now).inDays;
      if (daysLeft < 0) daysLeft = 0;
    }

    double score = 0;
    for (var p in products) {
      if (p['statut_financement'] == 'FINANCE') {
        score += 1;
      } else if (p['statut_financement'] == 'PARTIELLEMENT_FINANCE') {
        score += 0.5;
      }
    }
    int progressPercent = products.isEmpty ? 0 : ((score / products.length) * 100).toInt();

    return GestureDetector(
      onTap: () {
        context.pushNamed(
          AppRouteName.listDetail,
          pathParameters: {'id': listData['id']},
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Stack(
                children: [
                  Container(
                    height: 160,
                    width: double.infinity,
                    color: Colors.grey.shade100,
                    child: coverUrl != null && coverUrl.isNotEmpty
                        ? Image.network(
                            coverUrl, 
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.image_not_supported_outlined, size: 50, color: Colors.grey),
                          )
                        : const Icon(Icons.card_giftcard_rounded, size: 60, color: Colors.grey),
                  ),
                  if (eventDate != null)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3CD).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '$daysLeft JOURS RESTANTS',
                          style: const TextStyle(
                            color: Color(0xFF856404),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$eventName • $formattedDate',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Financé',
                        style: TextStyle(
                          fontSize: 15, 
                          color: Colors.blueGrey, 
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$progressPercent%',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF2E86AB),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: products.isEmpty ? 0 : (score / products.length),
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E86AB)),
                      minHeight: 8,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E86AB).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.card_giftcard_rounded, size: 16, color: Color(0xFF2E86AB)),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${products.length} articles',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
