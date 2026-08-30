import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/library_provider.dart';
import '../services/player_service.dart';

const List<String> kEqualizerPresets = [
  'Flat',
  'Pop',
  'Rock',
  'Classical',
  'Jazz',
  'Electronic',
  'Hip-Hop',
  'Bass Boost',
  'Vocal',
];

// Representasi EQ sederhana per preset (gain relatif, untuk referensi UI)
// Ketika paket EQ nyata ditambahkan, nilai ini langsung bisa dipakai.
const Map<String, List<double>> kPresetBands = {
  'Flat':       [0, 0, 0, 0, 0],
  'Pop':        [1, 2, 2, 1, 0],
  'Rock':       [3, 1, -1, 1, 3],
  'Classical':  [2, 0, 0, 0, 2],
  'Jazz':       [2, 1, 0, 1, 2],
  'Electronic': [3, 1, 0, 2, 3],
  'Hip-Hop':    [3, 2, 0, 0, 1],
  'Bass Boost': [4, 3, 0, 0, 0],
  'Vocal':      [-1, 0, 2, 2, 0],
};

const List<String> _bandLabels = ['60Hz', '250Hz', '1kHz', '4kHz', '16kHz'];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final lib = context.watch<LibraryProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          // ── TAMPILAN ──────────────────────────────────────────
          _SectionHeader('Tampilan'),
          RadioListTile<ThemeMode>(
            title: const Text('Ikuti sistem'),
            value: ThemeMode.system,
            groupValue: themeProvider.themeMode,
            onChanged: (v) => themeProvider.setThemeMode(v!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Terang'),
            value: ThemeMode.light,
            groupValue: themeProvider.themeMode,
            onChanged: (v) => themeProvider.setThemeMode(v!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Gelap'),
            value: ThemeMode.dark,
            groupValue: themeProvider.themeMode,
            onChanged: (v) => themeProvider.setThemeMode(v!),
          ),
          const Divider(),

          // ── ACCENT COLOR ──────────────────────────────────────
          _SectionHeader('Warna Aksen'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kAccentColorNames[themeProvider.accentColorIndex],
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500]),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(kAccentColors.length, (i) {
                    final isSelected = i == themeProvider.accentColorIndex;
                    return GestureDetector(
                      onTap: () => themeProvider.setAccentColor(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: kAccentColors[i],
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                  width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: kAccentColors[i].withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const Divider(),

          // ── PEMUTARAN ──────────────────────────────────────────
          _SectionHeader('Pemutaran'),
          SwitchListTile(
            title: const Text('Crossfade'),
            subtitle: const Text('Transisi antar lagu tanpa jeda (3 detik)'),
            secondary: const Icon(Icons.swap_horiz_outlined),
            value: PlayerService.instance.crossfadeEnabled,
            onChanged: (v) =>
                setState(() => PlayerService.instance.setCrossfadeEnabled(v)),
          ),
          const Divider(),

          // ── EQUALIZER ──────────────────────────────────────────
          _SectionHeader('Equalizer'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Pilih preset untuk menyesuaikan suara. Pengaturan disimpan antar sesi.',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
          // Preset chips
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: kEqualizerPresets.map((preset) {
                final isSelected = preset == themeProvider.equalizerPreset;
                return ChoiceChip(
                  label: Text(preset),
                  selected: isSelected,
                  onSelected: (_) => themeProvider.setEqualizerPreset(preset),
                );
              }).toList(),
            ),
          ),
          // EQ band visualizer
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _EqVisualizer(preset: themeProvider.equalizerPreset),
          ),
          const Divider(),

          // ── LIBRARY ────────────────────────────────────────────
          _SectionHeader('Library'),
          ListTile(
            leading: lib.isScanning
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.folder_open_outlined),
            title: const Text('Pindai File Musik'),
            subtitle: const Text(
                'Cek file musik baru/dihapus di HP (tanpa internet)'),
            onTap: lib.isScanning ? null : () => lib.forceScanDevice(),
          ),
          ListTile(
            leading: lib.isBulkScanningMetadata
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_sync_outlined),
            title: const Text('Scan Metadata yang Belum Ada'),
            subtitle: Text(lib.isBulkScanningMetadata
                ? 'Memproses ${lib.bulkScanProgress}/${lib.bulkScanTotal}...'
                : 'Ambil judul/artis/cover dari internet untuk lagu baru'),
            onTap: lib.isBulkScanningMetadata
                ? null
                : () => lib.bulkScanMetadata(onlyMissing: true),
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Scan Ulang Semua Metadata'),
            subtitle: const Text(
                'Ambil ulang dari internet untuk SEMUA lagu'),
            onTap: lib.isBulkScanningMetadata
                ? null
                : () => _confirmRescanAll(context, lib),
          ),
          if (lib.isBulkScanningMetadata)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: LinearProgressIndicator(
                value: lib.bulkScanTotal == 0
                    ? null
                    : lib.bulkScanProgress / lib.bulkScanTotal,
              ),
            ),
          const Divider(),

          // ── TENTANG ────────────────────────────────────────────
          _SectionHeader('Tentang'),
          const ListTile(
            leading: Icon(Icons.music_note_outlined),
            title: Text('Swara'),
            subtitle: Text('v1.6.0 \u00B7 by Niko'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _confirmRescanAll(BuildContext context, LibraryProvider lib) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan Ulang Semua'),
        content: Text(
            'Ambil ulang metadata untuk semua ${lib.totalCount} lagu dari internet? Ini butuh waktu lebih lama.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              lib.bulkScanMetadata(onlyMissing: false);
            },
            child: const Text('Mulai'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary)),
    );
  }
}

// Visual bar EQ sederhana untuk menunjukkan efek per preset
class _EqVisualizer extends StatelessWidget {
  final String preset;
  const _EqVisualizer({required this.preset});

  @override
  Widget build(BuildContext context) {
    final bands = kPresetBands[preset] ?? [0, 0, 0, 0, 0];
    final max = bands.map((b) => b.abs()).reduce((a, b) => a > b ? a : b);
    final normalizer = max < 1 ? 1.0 : max;
    final color = Theme.of(context).colorScheme.primary;

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(bands.length, (i) {
          final gain = bands[i];
          final ratio = (gain / normalizer).clamp(-1.0, 1.0);
          final barHeight = (ratio.abs() * 32 + 4).clamp(4.0, 44.0);

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                width: 24,
                height: barHeight,
                decoration: BoxDecoration(
                  color: gain > 0
                      ? color
                      : gain < 0
                          ? color.withOpacity(0.4)
                          : Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Text(_bandLabels[i],
                  style:
                      TextStyle(fontSize: 9, color: Colors.grey[500])),
            ],
          );
        }),
      ),
    );
  }
}
