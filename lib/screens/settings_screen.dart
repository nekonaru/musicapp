import 'package:flutter/material.dart';
import 'package:offline_music_player/l10n/gen/app_localizations.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
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

// Simple per-preset EQ representation (relative gains, for UI reference).
// When a real EQ package is added, these values can be used directly.
const Map<String, List<double>> kPresetBands = {
  'Flat': [0, 0, 0, 0, 0],
  'Pop': [1, 2, 2, 1, 0],
  'Rock': [3, 1, -1, 1, 3],
  'Classical': [2, 0, 0, 0, 2],
  'Jazz': [2, 1, 0, 1, 2],
  'Electronic': [3, 1, 0, 2, 3],
  'Hip-Hop': [3, 2, 0, 0, 1],
  'Bass Boost': [4, 3, 0, 0, 0],
  'Vocal': [-1, 0, 2, 2, 0],
};

const List<String> _bandLabels = ['60Hz', '250Hz', '1kHz', '4kHz', '16kHz'];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Guard against rapid successive taps on preferences:
  // the save future is awaited and input is disabled while saving.
  bool _savingPrefs = false;

  Future<void> _savePrefs(Future<void> Function() save) async {
    if (_savingPrefs) return;
    setState(() => _savingPrefs = true);
    try {
      await save();
    } finally {
      if (mounted) setState(() => _savingPrefs = false);
    }
  }

  // Returns the localized display name for an accent color index.
  String _accentName(AppLocalizations l10n, int index) {
    switch (index) {
      case 1:
        return l10n.settingsAccentBlue;
      case 2:
        return l10n.settingsAccentTeal;
      case 3:
        return l10n.settingsAccentGreen;
      case 4:
        return l10n.settingsAccentOrange;
      case 5:
        return l10n.settingsAccentRed;
      case 6:
        return l10n.settingsAccentDeepPurple;
      case 7:
        return l10n.settingsAccentPink;
      case 8:
        return l10n.settingsAccentCyan;
      case 9:
        return l10n.settingsAccentLightGreen;
      default:
        return l10n.settingsAccentPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final languageProvider = context.watch<LanguageProvider>();
    final lib = context.watch<LibraryProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          // -- LANGUAGE --
          _SectionHeader(l10n.languageSection),
          RadioGroup<String>(
            groupValue: languageProvider.locale.languageCode,
            onChanged: (v) {
              if (_savingPrefs || v == null) return;
              _savePrefs(() => languageProvider.setLocale(Locale(v)));
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: Text(l10n.languageEnglish),
                  subtitle: Text(l10n.languageSubtitle),
                  value: 'en',
                ),
                RadioListTile<String>(
                  title: Text(l10n.languageIndonesian),
                  subtitle: Text(l10n.languageSubtitle),
                  value: 'id',
                ),
              ],
            ),
          ),
          const Divider(),

          // -- APPEARANCE --
          _SectionHeader(l10n.settingsAppearance),
          RadioGroup<ThemeMode>(
            groupValue: themeProvider.themeMode,
            onChanged: (v) {
              if (_savingPrefs || v == null) return;
              _savePrefs(() => themeProvider.setThemeMode(v));
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<ThemeMode>(
                  title: Text(l10n.settingsFollowSystem),
                  value: ThemeMode.system,
                ),
                RadioListTile<ThemeMode>(
                  title: Text(l10n.settingsLight),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text(l10n.settingsDark),
                  value: ThemeMode.dark,
                ),
              ],
            ),
          ),
          const Divider(),

          // -- ACCENT COLOR --
          _SectionHeader(l10n.settingsAccentColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _accentName(l10n, themeProvider.accentColorIndex),
                  style:
                      TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(kAccentColors.length, (i) {
                    final isSelected = i == themeProvider.accentColorIndex;
                    return GestureDetector(
                      onTap: _savingPrefs
                          ? null
                          : () => _savePrefs(
                              () => themeProvider.setAccentColor(i)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: kAccentColors[i],
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color:
                                      Theme.of(context).colorScheme.outline,
                                  width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: kAccentColors[i]
                                        .withValues(alpha: 0.4),
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

          // -- PLAYBACK --
          _SectionHeader(l10n.settingsPlayback),
          SwitchListTile(
            title: Text(l10n.settingsCrossfade),
            subtitle: Text(l10n.settingsCrossfadeSubtitle),
            secondary: const Icon(Icons.swap_horiz_outlined),
            value: PlayerService.instance.crossfadeEnabled,
            onChanged: (v) =>
                setState(() => PlayerService.instance.setCrossfadeEnabled(v)),
          ),
          const Divider(),

          // -- EQUALIZER --
          _SectionHeader(l10n.settingsEqualizer),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              l10n.settingsEqualizerNote,
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
                  onSelected: _savingPrefs
                      ? null
                      : (_) => _savePrefs(
                          () => themeProvider.setEqualizerPreset(preset)),
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

          // -- LIBRARY --
          _SectionHeader(l10n.settingsLibrary),
          ListTile(
            leading: lib.isScanning
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.folder_open_outlined),
            title: Text(l10n.settingsScanFiles),
            subtitle: Text(l10n.settingsScanFilesSubtitle),
            onTap: lib.isScanning ? null : () => lib.forceScanDevice(),
          ),
          ListTile(
            leading: lib.isBulkScanningMetadata
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_sync_outlined),
            title: Text(l10n.settingsScanMissing),
            subtitle: Text(lib.isBulkScanningMetadata
                ? l10n.settingsScanProgress(lib.bulkScanProgress,
                    lib.bulkScanTotal)
                : l10n.settingsScanMissingSubtitle),
            onTap: lib.isBulkScanningMetadata
                ? null
                : () => lib.bulkScanMetadata(onlyMissing: true),
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: Text(l10n.settingsRescanAll),
            subtitle: Text(l10n.settingsRescanAllSubtitle),
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

          // -- ABOUT --
          _SectionHeader(l10n.settingsAbout),
          ListTile(
            leading: const Icon(Icons.music_note_outlined),
            title: const Text('Swara'),
            subtitle: Text(l10n.settingsAboutVersion),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _confirmRescanAll(BuildContext context, LibraryProvider lib) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsRescanTitle),
        content: Text(l10n.settingsRescanMessage(lib.totalCount)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              lib.bulkScanMetadata(onlyMissing: false);
            },
            child: Text(l10n.settingsRescanStart),
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

// Simple EQ bar visualizer for the selected preset (display only, no audio processing)
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
                          ? color.withValues(alpha: 0.4)
                          : Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Text(_bandLabels[i],
                  style: TextStyle(fontSize: 9, color: Colors.grey[500])),
            ],
          );
        }),
      ),
    );
  }
}
