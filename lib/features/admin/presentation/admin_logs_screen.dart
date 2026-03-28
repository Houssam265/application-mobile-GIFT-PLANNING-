import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/admin_log_model.dart';
import '../domain/admin_log_notifier.dart';
import '../domain/admin_log_state.dart';

class AdminLogsScreen extends ConsumerStatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  ConsumerState<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends ConsumerState<AdminLogsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Force a fresh fetch from DB every time this screen becomes active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(adminLogNotifierProvider);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(adminLogNotifierProvider.notifier).fetchLogs();
    }
  }

  Future<void> _selectDateRange() async {
    final state = ref.read(adminLogNotifierProvider);
    final initialRange = state.startDate != null && state.endDate != null
        ? DateTimeRange(start: state.startDate!, end: state.endDate!)
        : null;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: initialRange,
      locale: const Locale('fr', 'FR'),
    );

    if (picked != null) {
      ref.read(adminLogNotifierProvider.notifier).onDateRangeChanged(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminLogNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal d\'activité'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(adminLogNotifierProvider.notifier).fetchLogs(reset: true),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(state),
          const Divider(height: 1),
          Expanded(
            child: _buildLogsList(state, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(AdminLogState state) {
    final hasDateFilter = state.startDate != null;
    final dateFormat = DateFormat('dd/MM/yy');

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Flexible(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: state.actionFilter,
                  decoration: InputDecoration(
                    labelText: 'Type d\'action',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Toutes', overflow: TextOverflow.ellipsis)),
                    const DropdownMenuItem(value: 'SUSPEND_USER', child: Text('Suspension', overflow: TextOverflow.ellipsis)),
                    const DropdownMenuItem(value: 'REACTIVATE_USER', child: Text('Réactivation', overflow: TextOverflow.ellipsis)),
                    const DropdownMenuItem(value: 'DELETE_USER', child: Text('Suppression', overflow: TextOverflow.ellipsis)),
                    const DropdownMenuItem(value: 'ARCHIVE_LIST', child: Text('Archivage', overflow: TextOverflow.ellipsis)),
                    const DropdownMenuItem(value: 'REACTIVATE_LIST', child: Text('Ré-active liste', overflow: TextOverflow.ellipsis)),
                    const DropdownMenuItem(value: 'DELETE_LIST', child: Text('Supprim. liste', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) => ref.read(adminLogNotifierProvider.notifier).onActionFilterChanged(val),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: InkWell(
                  onTap: _selectDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                      color: hasDateFilter ? AppTheme.primary.withOpacity(0.05) : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: hasDateFilter ? AppTheme.primary : Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            hasDateFilter
                                ? '${dateFormat.format(state.startDate!)} - ${dateFormat.format(state.endDate!)}'
                                : 'Date',
                            style: TextStyle(
                              color: hasDateFilter ? AppTheme.primary : Colors.grey.shade700,
                              fontWeight: hasDateFilter ? FontWeight.bold : FontWeight.normal,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (state.actionFilter != null || hasDateFilter)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => ref.read(adminLogNotifierProvider.notifier).resetFilters(),
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Réinitialiser les filtres', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogsList(AdminLogState state, ThemeData theme) {
    if (state.status == AdminLogStatus.loading && state.logs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_edu, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('Aucun log trouvé.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(adminLogNotifierProvider.notifier).fetchLogs(reset: true),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: state.logs.length + (state.hasReachedMax ? 0 : 1),
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index >= state.logs.length) {
            return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
          }

          final log = state.logs[index];
          final color = _getActionColor(log.action);
          final icon = _getActionIcon(log.action);

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: color.withOpacity(0.12),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Action label + date
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              log.actionLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: color,
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  DateFormat('HH:mm').format(log.createdAt),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                Text(
                                  DateFormat('dd/MM/yy').format(log.createdAt),
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Target info — prominent
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color.withOpacity(0.2)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Icon(
                                  log.targetType == 'USER' ? Icons.person_outline : Icons.list_alt,
                                  size: 14,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(child: _buildCibleWidget(log, color)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        // Admin who did the action
                        RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            children: [
                              const TextSpan(text: 'Par '),
                              TextSpan(
                                text: log.adminName ?? 'Admin inconnu',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds a rich widget for the target (cible) of the action.
  Widget _buildCibleWidget(AdminLog log, Color color) {
    final shortId = log.targetId.length > 8
        ? log.targetId.substring(0, 8)
        : log.targetId;
    final typeLabel = log.targetType == 'USER' ? 'Utilisateur' : 'Liste';
    final name = log.targetName;
    final email = log.targetEmail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type + name (or fallback short ID)
        Text(
          name != null && name.isNotEmpty
              ? '$typeLabel · $name'
              : '$typeLabel · ID: $shortId…',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w600,
          ),
        ),
        // Email line (if available)
        if (email != null && email.isNotEmpty) ...
          [
            const SizedBox(height: 2),
            Text(
              email,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
      ],
    );
  }

  Color _getActionColor(String action) {
    if (action.contains('DELETE')) return AppTheme.error;
    if (action.contains('SUSPEND')) return Colors.orange;
    if (action.contains('ARCHIVE')) return Colors.blueGrey;
    if (action.contains('REACTIVATE')) return Colors.green;
    return Colors.blue;
  }

  IconData _getActionIcon(String action) {
    if (action.contains('USER')) {
      if (action.contains('DELETE')) return Icons.person_remove;
      if (action.contains('SUSPEND')) return Icons.person_off;
      return Icons.person;
    }
    if (action.contains('LIST')) {
      if (action.contains('DELETE')) return Icons.delete_sweep;
      if (action.contains('ARCHIVE')) return Icons.archive;
      return Icons.featured_play_list;
    }
    return Icons.settings;
  }
}
