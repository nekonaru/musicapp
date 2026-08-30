import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/db_helper.dart';
import '../models/song.dart';
import '../services/player_service.dart';
import '../utils/format.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  Map<DateTime, int> _daily = {};
  List<MapEntry<int, int>> _topSongIds = [];
  List<MapEntry<String, int>> _topArtists = [];
  Map<String, int> _genreDist = {};
  Map<int, Song> _songLookup = {};
  int _totalSongs = 0;
  int _totalListeningMs = 0;
  int _thisMonthMs = 0;
  List<Song> _neverPlayed = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);

    final daily = await DBHelper.instance.getDailyListeningLast7Days();
    final topSongs = await DBHelper.instance.getTopSongIds(limit: 5);
    final topArtists = await DBHelper.instance.getTopArtists(limit: 5);
    final genreDist = await DBHelper.instance.getGenreDistribution();
    final allSongs = await DBHelper.instance.getAllSongs();
    final totalMs = await DBHelper.instance.getTotalListeningMs();
    final monthMs = await DBHelper.instance.getThisMonthListeningMs();
    final neverPlayed = await DBHelper.instance.getNeverPlayedSongs();

    if (mounted) {
      setState(() {
        _daily = daily;
        _topSongIds = topSongs;
        _topArtists = topArtists;
        _genreDist = genreDist;
        _songLookup = {for (final s in allSongs) s.id: s};
        _totalSongs = allSongs.length;
        _totalListeningMs = totalMs;
        _thisMonthMs = monthMs;
        _neverPlayed = neverPlayed;
        _loading = false;
      });
    }
  }

  bool get _hasAnyData =>
      _daily.values.any((ms) => ms > 0) || _topSongIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasAnyData) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 80),
            Icon(Icons.bar_chart_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text(
              'Dashboard kosong',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),
            Text(
              'Statistik pendengaran akan muncul setelah kamu mulai memutar lagu.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
            const SizedBox(height: 32),
            // Ringkasan dasar meski belum ada history
            _StatCard(
              icon: Icons.library_music_outlined,
              value: '$_totalSongs',
              label: 'Total lagu di library',
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      );
    }

    final totalHours = _totalListeningMs / 3600000;
    final monthHours = _thisMonthMs / 3600000;
    final weekMs = _daily.values.fold<int>(0, (a, b) => a + b);
    final weekHours = weekMs / 3600000;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Statistik ringkasan
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.library_music_outlined,
                  value: '$_totalSongs',
                  label: 'Total lagu',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.headphones_outlined,
                  value: '${totalHours.toStringAsFixed(0)} jam',
                  label: 'Total didengar',
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.today_outlined,
                  value: '${monthHours.toStringAsFixed(1)} jam',
                  label: 'Bulan ini',
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Grafik 7 hari
          _SectionCard(
            icon: Icons.show_chart,
            title: 'Jam Dengar 7 Hari Terakhir',
            trailing: Text('${weekHours.toStringAsFixed(1)} jam total',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            child: SizedBox(height: 160, child: _buildBarChart()),
          ),
          const SizedBox(height: 14),

          // Top 5 lagu (interaktif)
          if (_topSongIds.isNotEmpty)
            _SectionCard(
              icon: Icons.music_note_outlined,
              title: 'Top 5 Lagu',
              child: Column(
                children: [
                  for (int i = 0; i < _topSongIds.length; i++) ...[
                    _RankTile(
                      rank: i + 1,
                      title: _songLookup[_topSongIds[i].key]?.title ??
                          'Lagu #${_topSongIds[i].key}',
                      subtitle: _songLookup[_topSongIds[i].key]?.artist,
                      trailing: '${_topSongIds[i].value}x diputar',
                      maxValue: _topSongIds.first.value,
                      value: _topSongIds[i].value,
                      onTap: () {
                        final song = _songLookup[_topSongIds[i].key];
                        if (song != null) {
                          PlayerService.instance
                              .setQueueAndPlay([song], 0);
                        }
                      },
                    ),
                    if (i < _topSongIds.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          if (_topSongIds.isNotEmpty) const SizedBox(height: 14),

          // Top artis (interaktif)
          if (_topArtists.isNotEmpty)
            _SectionCard(
              icon: Icons.person_outline,
              title: 'Top 5 Artis',
              child: Column(
                children: [
                  for (int i = 0; i < _topArtists.length; i++) ...[
                    _RankTile(
                      rank: i + 1,
                      title: _topArtists[i].key,
                      trailing: '${_topArtists[i].value}x diputar',
                      maxValue: _topArtists.first.value,
                      value: _topArtists[i].value,
                    ),
                    if (i < _topArtists.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          if (_topArtists.isNotEmpty) const SizedBox(height: 14),

          // Genre distribusi
          if (_genreDist.isNotEmpty)
            _SectionCard(
              icon: Icons.category_outlined,
              title: 'Distribusi Genre',
              trailing: Text('${_genreDist.length} genre',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              child: _buildGenreList(),
            ),
          if (_genreDist.isNotEmpty) const SizedBox(height: 14),

          // Belum pernah diputar
          if (_neverPlayed.isNotEmpty)
            _SectionCard(
              icon: Icons.not_interested_outlined,
              title: 'Belum Pernah Diputar',
              trailing: GestureDetector(
                onTap: () => _showNeverPlayed(),
                child: Text('${_neverPlayed.length} lagu',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600)),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  children: [
                    Text(
                      '${_neverPlayed.length} lagu di library kamu belum pernah diputar.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showNeverPlayed,
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Putar Semua'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_neverPlayed.isNotEmpty) const SizedBox(height: 14),

          // Streak info
          _SectionCard(
            icon: Icons.local_fire_department_outlined,
            title: 'Aktivitas Minggu Ini',
            child: _buildWeekActivity(),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreList() {
    final entries = _genreDist.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.isEmpty ? 1 : entries.first.value;
    return Column(
      children: entries.take(6).map((e) {
        final ratio = (e.value / max).clamp(0.04, 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(e.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation(
                        Theme.of(context).colorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${e.value}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWeekActivity() {
    final days = _daily.keys.toList()..sort();
    final dayNames = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
    if (days.isEmpty) return const Text('Belum ada aktivitas minggu ini.');
    final activeDays = days.where((d) => (_daily[d] ?? 0) > 0).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$activeDays dari 7 hari aktif mendengarkan',
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: days.map((d) {
            final ms = _daily[d] ?? 0;
            final isToday = d.day == DateTime.now().day &&
                d.month == DateTime.now().month;
            final hasData = ms > 0;
            return Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: hasData
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                    border: isToday
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2)
                        : null,
                  ),
                  child: Center(
                    child: hasData
                        ? Icon(Icons.headphones,
                            size: 14,
                            color: Theme.of(context).colorScheme.onPrimary)
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(dayNames[d.weekday % 7],
                    style: TextStyle(
                        fontSize: 10,
                        color: isToday
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[500])),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showNeverPlayed() {
    if (_neverPlayed.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.not_interested_outlined),
                  const SizedBox(width: 8),
                  Text('${_neverPlayed.length} lagu belum pernah diputar',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      PlayerService.instance.setQueueAndPlay(_neverPlayed, 0);
                    },
                    child: const Text('Putar Semua'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: _neverPlayed.length,
                itemExtent: 64,
                itemBuilder: (context, i) {
                  final s = _neverPlayed[i];
                  return ListTile(
                    dense: true,
                    title: Text(s.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(s.artist,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(formatDuration(s.durationMs),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    onTap: () {
                      Navigator.pop(ctx);
                      PlayerService.instance.setQueueAndPlay(_neverPlayed, i);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    final days = _daily.keys.toList()..sort();
    final maxMs = _daily.values.isEmpty
        ? 1
        : _daily.values.reduce((a, b) => a > b ? a : b);
    final maxHours = (maxMs / 3600000).clamp(0.5, double.infinity);
    final color = Theme.of(context).colorScheme.primary;

    return BarChart(
      BarChartData(
        maxY: maxHours.toDouble() + 0.5,
        barGroups: [
          for (int i = 0; i < days.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: _daily[days[i]]! / 3600000,
                width: 20,
                borderRadius: BorderRadius.circular(6),
                color: color,
              )
            ])
        ],
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= days.length) return const SizedBox();
                const hariSingkat = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
                final isToday = days[idx].day == DateTime.now().day;
                return Text(
                  hariSingkat[days[idx].weekday % 7],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isToday ? color : Colors.grey,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxHours / 3 < 0.1 ? 0.1 : maxHours / 3,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
              strokeWidth: 1,
            )),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final h = rod.toY;
              final mins = (h * 60).round();
              return BarTooltipItem(
                mins < 60 ? '${mins}m' : '${h.toStringAsFixed(1)}j',
                TextStyle(color: Theme.of(context).colorScheme.onPrimary),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SHARED COMPONENTS
// ─────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatCard({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;
  const _SectionCard(
      {required this.icon,
      required this.title,
      required this.child,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  final int? rank;
  final String title;
  final String? subtitle;
  final String trailing;
  final int value;
  final int maxValue;
  final VoidCallback? onTap;
  const _RankTile({
    this.rank,
    required this.title,
    this.subtitle,
    required this.trailing,
    required this.value,
    required this.maxValue,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final ratio = maxValue > 0 ? (value / maxValue).clamp(0.03, 1.0) : 0.03;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (rank != null) ...[
              SizedBox(
                width: 22,
                child: Text('$rank',
                    style: TextStyle(
                        fontSize: 13,
                        color: rank! <= 3 ? color : Colors.grey[500],
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(width: 8),
                      Text(trailing,
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      if (onTap != null) const SizedBox(width: 4),
                      if (onTap != null)
                        Icon(Icons.play_circle_outline,
                            size: 16, color: Colors.grey[400]),
                    ],
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: ratio.toDouble(),
                      minHeight: 3,
                      backgroundColor: color.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
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
