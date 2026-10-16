import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swara/l10n/gen/app_localizations.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/library_provider.dart';
import '../services/backup_service.dart';
import '../services/equalizer_service.dart';
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

  // State for the Data section (backup export/import + art cache).
  bool _busyData = false;
  bool _loadingArt = false;
  ArtCacheUsage? _artUsage;

  @override
  void initState() {
    super.initState();
    _refreshArtCache();
  }

  // Short snackbar helper with a mounted guard.
  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // Human readable byte count for the art cache row.
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _refreshArtCache() async {
    if (_loadingArt) return;
    setState(() => _loadingArt = true);
    try {
      final usage = await BackupService.artCacheUsage();
      if (!mounted) return;
      setState(() => _artUsage = usage);
    } catch (e) {
      _showSnack(AppLocalizations.of(context)!.dataMeasureFailed(e.toString()));
    } finally {
      if (mounted) setState(() => _loadingArt = false);
    }
  }

  // Export the library to JSON and show size + copy button in a dialog.
  Future<void> _exportData() async {
    if (_busyData) return;
    setState(() => _busyData = true);
    try {
      final json = await BackupService.exportLibrary();
      if (!mounted) return;
      setState(() => _busyData = false);
      final l10n = AppLocalizations.of(context)!;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.dataExportTitle),
          content: Text(l10n.dataExportReady(json.length, _formatBytes(json.length))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.close),
            ),
            FilledButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: json));
                if (!mounted) return;
                Navigator.pop(ctx);
                _showSnack(l10n.dataCopied);
              },
              child: Text(l10n.dataCopy),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyData = false);
      _showSnack(AppLocalizations.of(context)!
          .dataExportFailed(e.toString()));
    }
  }

  // Ask for pasted JSON, offer a paste-from-clipboard button, then import.
  Future<void> _importData() async {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    final pasted = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dataImportTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.dataImportPrompt),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: l10n.dataImportHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              controller.text = data?.text ?? '';
            },
            child: Text(l10n.dataPaste),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.dataImportAction),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted) return;
    if (pasted == null || pasted.isEmpty) return;

    // Confirm before writing anything to the DB.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dataConfirmImportTitle),
        content: Text(l10n.dataConfirmImportMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.dataImportAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyData = true);
    try {
      final result = await BackupService.importLibrary(pasted);
      if (!mounted) return;
      // Refresh library views so restored favorites show up at once.
      try {
        await context.read<LibraryProvider>().loadFromDb();
      } catch (_) {
        // Non fatal: import already succeeded.
      }
      try {
        await context.read<PlaylistProvider>().load();
      } catch (_) {
        // Non fatal: playlist screen reloads on open.
      }
      if (!mounted) return;
      setState(() => _busyData = false);
      _showSnack(AppLocalizations.of(context)!.dataImportDone(
          result.playlistsCreated,
          result.playlistMembersAdded,
          result.favoritesRestored,
          result.listeningEntriesRestored));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyData = false);
      _showSnack(
          AppLocalizations.of(context)!.dataImportFailed(e.toString()));
    }
  }

  // Confirm then delete cached art files and clear DB references.
  Future<void> _clearArtCache() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dataClearConfirmTitle),
        content: Text(l10n
            .dataClearConfirmMessage(_artUsage?.files ?? 0)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.dataClear),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyData = true);
    try {
      final deleted = await BackupService.clearArtCache();
      try {
        await context.read<LibraryProvider>().loadFromDb();
      } catch (_) {
        // Non fatal: list refresh only.
      }
      await _refreshArtCache();
      if (!mounted) return;
      setState(() => _busyData = false);
      _showSnack(AppLocalizations.of(context)!.dataArtCleared(deleted));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyData = false);
      _showSnack(
          AppLocalizations.of(context)!.dataClearFailed(e.toString()));
    }
  }

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
                      : (_) => _savePrefs(() async {
                            await themeProvider.setEqualizerPreset(preset);
                            await EqualizerService.instance
                                .applyPreset(preset);
                          }),
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

          // -- DATA (backup + cache) --
          _SectionHeader(AppLocalizations.of(context)!.dataSection),
          ListTile(
            leading: _busyData
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_outlined),
            title: Text(AppLocalizations.of(context)!.dataExport),
            subtitle:
                Text(AppLocalizations.of(context)!.dataExportSubtitle),
            onTap: _busyData ? null : _exportData,
          ),
          ListTile(
            leading: _busyData
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_outlined),
            title: Text(AppLocalizations.of(context)!.dataImport),
            subtitle:
                Text(AppLocalizations.of(context)!.dataImportSubtitle),
            onTap: _busyData ? null : _importData,
          ),
          ListTile(
            leading: _loadingArt
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.image_outlined),
            title: Text(AppLocalizations.of(context)!.dataArtCache),
            subtitle: Text(_artUsage == null
                ? AppLocalizations.of(context)!.dataArtCacheMeasuring
                : AppLocalizations.of(context)!.dataArtCacheUsage(
                    _formatBytes(_artUsage!.bytes), _artUsage!.files)),
            trailing: TextButton(
              onPressed:
                  (_busyData || _loadingArt) ? null : () => _refreshArtCache(),
              child: Text(AppLocalizations.of(context)!.dataRefresh),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(AppLocalizations.of(context)!.dataClearArtCache),
            subtitle: Text(
                AppLocalizations.of(context)!.dataClearArtCacheSubtitle),
            onTap: (_busyData || _loadingArt) ? null : _clearArtCache,
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

// Simple EQ bar visualizer mirroring the selected preset curve.
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
