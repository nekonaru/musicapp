import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/db_helper.dart';
import '../models/song.dart';

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
  Map<String, int> _regionDist = {};
  Map<int, Song> _songLookup = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Dipanggil dari HomeScreen tiap kali tab Dashboard dipilih, supaya data
  /// selalu terbaru (misalnya abis dengar lagu baru di tab lain) tanpa perlu
  /// pull-to-refresh manual - soalnya widget ini tidak pernah di-dispose
  /// selama sesi app (dipertahankan oleh IndexedStack).
  Future<void> reload() => _load();

  Future<void> _load() async {
    final daily = await DBHelper.instance.getDailyListeningLast7Days();
    final topSongs = await DBHelper.instance.getTopSongIds(limit: 5);
    final topArtists = await DBHelper.instance.getTopArtists(limit: 5);
    final genreDist = await DBHelper.instance.getGenreDistribution();
    final regionDist = await DBHelper.instance.getRegionDistribution();
    final allSongs = await DBHelper.instance.getAllSongs();

    setState(() {
      _daily = daily;
      _topSongIds = topSongs;
      _topArtists = topArtists;
      _genreDist = genreDist;
      _regionDist = regionDist;
      _songLookup = {for (final s in allSongs) s.id: s};
      _loading = false;
    });
  }

  bool get _hasAnyListeningData => _daily.values.any((ms) => ms > 0);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasAnyListeningData && _topSongIds.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 80),
            Icon(Icons.bar_chart_outlined, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Belum ada data dengar',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Statistik pendengaran kamu bakal muncul di sini setelah\nmulai memutar lagu.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    final totalMs = _daily.values.fold<int>(0, (a, b) => a + b);
    final totalHours = totalMs / 3600000;
    final avgPerDay = totalHours / 7;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Ringkasan cepat, biar dashboard langsung kasih info penting
          // sebelum masuk ke detail per section.
          Row(
            children: [
              Expanded(child: _SummaryStat(
                icon: Icons.headphones_outlined,
                value: '${totalHours.toStringAsFixed(1)} jam',
                label: '7 hari terakhir',
              )),
              const SizedBox(width: 10),
              Expanded(child: _SummaryStat(
                icon: Icons.today_outlined,
                value: '${avgPerDay.toStringAsFixed(1)} jam',
                label: 'Rata-rata/hari',
              )),
              const SizedBox(width: 10),
              Expanded(child: _SummaryStat(
                icon: Icons.category_outlined,
                value: '${_genreDist.length}',
                label: 'Genre terdeteksi',
              )),
            ],
          ),
          const SizedBox(height: 20),

          _SectionCard(
            icon: Icons.show_chart,
            title: 'Jam Dengar 7 Hari Terakhir',
            child: SizedBox(height: 180, child: _buildBarChart()),
          ),
          const SizedBox(height: 16),

          if (_topSongIds.isNotEmpty)
            _SectionCard(
              icon: Icons.music_note_outlined,
              title: 'Top 5 Lagu',
              child: Column(
                children: [
                  for (int i = 0; i < _topSongIds.length; i++)
                    _RankTile(
                      rank: i + 1,
                      title: _songLookup[_topSongIds[i].key]?.title ?? 'Lagu #${_topSongIds[i].key}',
                      subtitle: _songLookup[_topSongIds[i].key]?.artist,
                      trailing: '${_topSongIds[i].value}x',
                      maxValue: _topSongIds.first.value,
                      value: _topSongIds[i].value,
                    ),
                ],
              ),
            ),
          if (_topSongIds.isNotEmpty) const SizedBox(height: 16),

          if (_topArtists.isNotEmpty)
            _SectionCard(
              icon: Icons.person_outline,
              title: 'Top 5 Artis',
              child: Column(
                children: [
                  for (int i = 0; i < _topArtists.length; i++)
                    _RankTile(
                      rank: i + 1,
                      title: _topArtists[i].key,
                      trailing: '${_topArtists[i].value}x',
                      maxValue: _topArtists.first.value,
                      value: _topArtists[i].value,
                    ),
                ],
              ),
            ),
          if (_topArtists.isNotEmpty) const SizedBox(height: 16),

          if (_genreDist.isNotEmpty)
            _SectionCard(
              icon: Icons.category_outlined,
              title: 'Genre',
              child: _buildDistList(_genreDist),
            ),
          if (_genreDist.isNotEmpty) const SizedBox(height: 16),

          if (_regionDist.isNotEmpty)
            _SectionCard(
              icon: Icons.public_outlined,
              title: 'Asal Region Lagu',
              child: _buildDistList(_regionDist),
            ),
        ],
      ),
    );
  }

  Widget _buildDistList(Map<String, int> dist) {
    final maxValue = dist.values.reduce((a, b) => a > b ? a : b);
    final entries = dist.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      children: [
        for (final e in entries)
          _RankTile(
            title: e.key,
            trailing: '${e.value} lagu',
            maxValue: maxValue,
            value: e.value,
          ),
      ],
    );
  }

  Widget _buildBarChart() {
    final days = _daily.keys.toList()..sort();
    final maxMs = _daily.values.isEmpty
        ? 1
        : _daily.values.reduce((a, b) => a > b ? a : b);
    final maxHours = (maxMs / 3600000).clamp(1, double.infinity);

    return BarChart(
      BarChartData(
        maxY: maxHours.toDouble() + 0.5,
        barGroups: [
          for (int i = 0; i < days.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: _daily[days[i]]! / 3600000,
                width: 18,
                borderRadius: BorderRadius.circular(4),
                color: Theme.of(context).colorScheme.primary,
              )
            ])
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 32),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= days.length) return const SizedBox();
                const hariSingkat = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
                return Text(hariSingkat[days[idx].weekday % 7],
                    style: const TextStyle(fontSize: 11));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

/// Kartu ringkasan kecil buat satu angka penting (jam dengar, rata-rata, dst).
class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _SummaryStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

/// Pembungkus konsisten buat tiap section dashboard: judul + ikon di atas,
/// konten di bawah, semua dalam satu card biar terstruktur dan rapi.
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _SectionCard({required this.icon, required this.title, required this.child});

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
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Satu baris item berperingkat, dengan bar proporsional tipis di bawahnya
/// biar langsung kelihatan mana yang paling menonjol tanpa perlu baca angka.
class _RankTile extends StatelessWidget {
  final int? rank;
  final String title;
  final String? subtitle;
  final String trailing;
  final int value;
  final int maxValue;
  const _RankTile({
    this.rank,
    required this.title,
    this.subtitle,
    required this.trailing,
    required this.value,
    required this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final ratio = maxValue > 0 ? (value / maxValue).clamp(0.03, 1.0) : 0.03;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (rank != null) ...[
            SizedBox(
              width: 22,
              child: Text('$rank', style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w600)),
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
                      child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 8),
                    Text(trailing, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
                  ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: ratio.toDouble(),
                    minHeight: 4,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
