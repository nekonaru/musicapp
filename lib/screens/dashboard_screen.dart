import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/db_helper.dart';
import '../models/song.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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

  Future<void> _load() async {
    final daily = await DBHelper.instance.getDailyListeningLast7Days();
    final topSongs = await DBHelper.instance.getTopSongIds();
    final topArtists = await DBHelper.instance.getTopArtists();
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Jam Dengar 7 Hari Terakhir',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(height: 200, child: _buildBarChart()),
          const SizedBox(height: 28),
          const Text('Lagu Paling Sering Didengar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._topSongIds.map((e) {
            final song = _songLookup[e.key];
            return ListTile(
              leading: const Icon(Icons.music_note),
              title: Text(song?.title ?? 'Lagu #${e.key}'),
              subtitle: Text(song?.artist ?? ''),
              trailing: Text('${e.value}x'),
            );
          }),
          const SizedBox(height: 28),
          const Text('Artis Favorit',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._topArtists.map((e) => ListTile(
                leading: const Icon(Icons.person),
                title: Text(e.key),
                trailing: Text('${e.value}x'),
              )),
          const SizedBox(height: 28),
          const Text('Genre',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildDistList(_genreDist),
          const SizedBox(height: 28),
          const Text('Asal Region Lagu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildDistList(_regionDist),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDistList(Map<String, int> dist) {
    return Column(
      children: dist.entries
          .map((e) => ListTile(
                dense: true,
                title: Text(e.key),
                trailing: Text('${e.value} lagu'),
              ))
          .toList(),
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
