import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';

/// Carte liste pour le tableau de bord (GP-17) : titre, dates, nb produits,
/// % financé, jours restants, badge de statut liste.
class DashboardListCard extends StatelessWidget {
  const DashboardListCard({super.key, required this.listData});

  final Map<String, dynamic> listData;

  static String _formatDate(DateTime date) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final title = (listData['titre'] ?? 'Liste').toString();
    final eventName = (listData['nom_evenement'] ?? 'Événement').toString();
    final eventDateStr = listData['date_evenement'];
    final creationStr = listData['date_creation'];
    final coverUrl = listData['photo_couverture_url'] as String?;
    final statutRaw = (listData['statut'] ?? 'ACTIVE').toString().toUpperCase();
    final products = listData['produits'] as List<dynamic>? ?? [];

    DateTime? eventDate;
    if (eventDateStr != null) {
      eventDate = DateTime.tryParse(eventDateStr.toString());
    }
    DateTime? creationDate;
    if (creationStr != null) {
      creationDate = DateTime.tryParse(creationStr.toString());
    }

    String formattedEventDate = '';
    String daysLabel = '';
    final isArchived = statutRaw == 'ARCHIVEE';

    if (eventDate != null) {
      formattedEventDate = _formatDate(eventDate);
      final now = DateTime.now();
      final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
      final today = DateTime(now.year, now.month, now.day);
      final diff = eventDay.difference(today).inDays;

      if (isArchived) {
        daysLabel = '—';
      } else if (diff < 0) {
        daysLabel = 'Événement passé';
      } else if (diff == 0) {
        daysLabel = 'Aujourd’hui';
      } else if (diff == 1) {
        daysLabel = '1 jour restant';
      } else {
        daysLabel = '$diff jours restants';
      }
    } else {
      daysLabel = isArchived ? '—' : '—';
    }

    double score = 0;
    for (final p in products) {
      final m = p as Map<String, dynamic>;
      if (m['statut_financement'] == 'FINANCE') {
        score += 1;
      } else if (m['statut_financement'] == 'PARTIELLEMENT_FINANCE') {
        score += 0.5;
      }
    }
    final progressPercent =
        products.isEmpty ? 0 : ((score / products.length) * 100).round();

    final statusLabel = isArchived ? 'Archivée' : 'Active';
    final statusColor = isArchived
        ? const Color(0xFF6B7280)
        : const Color(0xFF059669);
    final statusBg = isArchived
        ? const Color(0xFFF3F4F6)
        : const Color(0xFFD1FAE5);

    return GestureDetector(
      onTap: () {
        context.pushNamed(
          AppRouteName.listDetail,
          pathParameters: {'id': listData['id'].toString()},
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
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
                    height: 152,
                    width: double.infinity,
                    color: Colors.grey.shade100,
                    child: coverUrl != null && coverUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (_, _) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.image_not_supported_outlined,
                              size: 50,
                              color: Colors.grey,
                            ),
                          )
                        : const Icon(
                            Icons.card_giftcard_rounded,
                            size: 60,
                            color: Colors.grey,
                          ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  if (!isArchived && eventDate != null && daysLabel.isNotEmpty)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                          daysLabel.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF856404),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                      letterSpacing: -0.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.event_rounded, size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          formattedEventDate.isEmpty
                              ? eventName
                              : '$eventName • $formattedEventDate',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (creationDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Créée le ${_formatDate(creationDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.hourglass_top_rounded, size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isArchived
                              ? 'Jours restants : —'
                              : (eventDate == null
                                  ? 'Jours restants : —'
                                  : 'Jours restants : $daysLabel'),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Financé',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$progressPercent%',
                        style: const TextStyle(
                          fontSize: 17,
                          color: Color(0xFF2E86AB),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: products.isEmpty ? 0 : (score / products.length).clamp(0.0, 1.0),
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E86AB)),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E86AB).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: Color(0xFF2E86AB),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${products.length} produit${products.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 14,
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
}
