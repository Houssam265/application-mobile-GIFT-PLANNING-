import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


import '../../profile/domain/profile_notifier.dart';
import '../domain/admin_dashboard_notifier.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileNotifierProvider);
    final dashboardState = ref.watch(adminDashboardNotifierProvider);
    
    // Quick security check
    if (!profileState.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Accès refusé')),
        body: const Center(
          child: Text('Vous n\'avez pas les droits d\'administration.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.grey),
            onPressed: () => Supabase.instance.client.auth.signOut(),
            tooltip: 'Se déconnecter',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.people, color: Colors.indigo),
              title: const Text('Gestion des utilisateurs', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Rechercher, suspendre ou supprimer des comptes.'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                context.pushNamed('admin-users');
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.featured_play_list, color: Colors.blue),
              title: const Text('Gestion des listes', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Voir toutes les listes, forcer l\'archivage, modération.'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                context.pushNamed('admin-lists');
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.history_rounded, color: Colors.orange),
              title: const Text('Journal d\'activité', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Historique des actions effectuées par les administrateurs.'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                context.pushNamed('admin-logs');
              },
            ),
          ),
          // Activité : Inscriptions par semaine
          const SizedBox(height: 24),
          Text(
            'Inscriptions par semaine',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: dashboardState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : dashboardState.error != null
                        ? Center(child: Text('Erreur: ${dashboardState.error}'))
                        : _buildUsersChart(dashboardState.usersPerWeek, context),
              ),
            ),
          ),

          // Activité : Listes par mois
          const SizedBox(height: 24),
          Text(
            'Listes créées par mois',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: dashboardState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : dashboardState.error != null
                        ? Center(child: Text('Erreur: ${dashboardState.error}'))
                        : _buildListsChart(dashboardState.listsPerMonth, context),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildUsersChart(Map<DateTime, int> data, BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('Aucune donnée disponible.'));
    }

    final entries = data.entries.toList();
    double maxY = 0;
    for (final e in entries) {
      if (e.value > maxY) maxY = e.value.toDouble();
    }
    if (maxY == 0) maxY = 5;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.blueAccent,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final val = rod.toY.toInt();
              final date = entries[group.x.toInt()].key;
              return BarTooltipItem(
                '${date.day}/${date.month} \n$val inscrits',
                const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) return const SizedBox.shrink();
                final date = entries[index].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${date.day}/${date.month}',
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value % 1 != 0) return const SizedBox.shrink();
                return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(entries.length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: entries[index].value.toDouble(),
                color: Colors.blue,
                width: 16,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildListsChart(Map<DateTime, int> data, BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('Aucune donnée disponible.'));
    }

    final entries = data.entries.toList();
    double maxY = 0;
    for (final e in entries) {
      if (e.value > maxY) maxY = e.value.toDouble();
    }
    if (maxY == 0) maxY = 5;

    final spots = List.generate(entries.length, (index) {
      return FlSpot(index.toDouble(), entries[index].value.toDouble());
    });

    final monthNames = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.2,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.indigoAccent,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final date = entries[spot.x.toInt()].key;
                return LineTooltipItem(
                  '${monthNames[date.month - 1]} ${date.year}\n${spot.y.toInt()} listes',
                  const TextStyle(color: Colors.white),
                );
              }).toList();
            },
          ),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) return const SizedBox.shrink();
                final date = entries[index].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    monthNames[date.month - 1],
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value % 1 != 0) return const SizedBox.shrink();
                return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.indigo,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.indigo.withAlpha(51),
            ),
          ),
        ],
      ),
    );
  }
}
