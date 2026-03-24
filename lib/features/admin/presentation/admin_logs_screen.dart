import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
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
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color, size: 20),
              ),
              title: Text(
                log.actionLabel,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                      children: [
                        const TextSpan(text: 'Par '),
                        TextSpan(
                          text: log.adminName ?? 'Admin inconnu',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    'ID Cible: ${log.targetId}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontFamily: 'monospace'),
                  ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('HH:mm').format(log.createdAt),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    DateFormat('dd/MM/yy').format(log.createdAt),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
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
