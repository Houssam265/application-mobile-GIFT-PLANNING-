import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_links.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_button.dart';
import '../../lists/data/list_repository.dart';

class JoinPreviewScreen extends StatefulWidget {
  const JoinPreviewScreen({super.key, required this.code});

  final String code;

  @override
  State<JoinPreviewScreen> createState() => _JoinPreviewScreenState();
}

class _JoinPreviewScreenState extends State<JoinPreviewScreen> {
  final _repository = ListRepository();

  bool _isLoading = true;
  bool _isJoining = false;
  Map<String, dynamic>? _preview;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  String get _normalizedCode => widget.code.split('?').first.trim();

  String get _shareUrl => AppLinks.joinUrl(_normalizedCode);

  Future<void> _loadPreview() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repository.getJoinPreviewByCode(_normalizedCode);
      if (!mounted) return;
      setState(() {
        _preview = data;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preview = null;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _shareUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lien copié dans le presse-papiers.')),
    );
  }

  Future<void> _shareLink() async {
    await SharePlus.instance.share(ShareParams(text: _shareUrl));
  }

  Future<void> _onJoinPressed() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      final redirect = Uri.encodeComponent('/join/$_normalizedCode');
      context.go('/login?redirect=$redirect');
      return;
    }

    final listId = _preview?['id'] as String?;
    if (listId == null || listId.isEmpty) return;
    
    setState(() => _isJoining = true);
    try {
      final status = await _repository.joinList(listId);
      if (!mounted) return;
      if (status == 'ALREADY_MEMBER') {
        context.goNamed(AppRouteName.listDetail, pathParameters: {'id': listId});
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demande envoyée au propriétaire.')),
      );
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      final errorStr = e.toString();
      if (errorStr.contains('déjà propriétaire') || errorStr.contains('déjà partie')) {
        context.goNamed(AppRouteName.listDetail, pathParameters: {'id': listId});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorStr.replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return 'Date non définie';
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return rawDate;
    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/'
        '${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Aperçu de la liste')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _preview == null
              ? const Center(
                  child: Text('Lien invalide ou liste indisponible.'),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCover(theme),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _preview?['titre'] as String? ?? 'Liste',
                                  style: theme.textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _preview?['nom_evenement'] as String? ??
                                        'Événement',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    const Icon(Icons.event, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDate(
                                        _preview?['date_evenement'] as String?,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.card_giftcard_outlined,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${_preview?['products_count'] ?? 0} produits',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _copyLink,
                            icon: const Icon(Icons.copy),
                            label: const Text('Copier le lien'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _shareLink,
                            icon: const Icon(Icons.share),
                            label: const Text('Partager'),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    AppButton(
                      label: _isJoining ? 'En cours...' : 'Rejoindre',
                      onPressed: _isJoining ? null : _onJoinPressed,
                      variant: AppButtonVariant.primary,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCover(ThemeData theme) {
    final imageUrl = _preview?['photo_couverture_url'] as String?;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildCoverFallback(theme),
      );
    }

    return _buildCoverFallback(theme);
  }

  Widget _buildCoverFallback(ThemeData theme) {
    return Container(
      height: 180,
      width: double.infinity,
      color: theme.colorScheme.surfaceVariant,
      child: Icon(
        Icons.celebration_outlined,
        size: 52,
        color: theme.colorScheme.primary,
      ),
    );
  }
}
