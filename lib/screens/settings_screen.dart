import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/library_provider.dart';
import '../services/player_service.dart';

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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Tampilan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('Library', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            leading: lib.isScanning
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.folder_open_outlined),
            title: const Text('Scan Files'),
            subtitle: const Text('Cek file musik baru/dihapus di HP (tanpa internet, biasanya otomatis tiap buka app)'),
            onTap: lib.isScanning ? null : () => lib.scanDevice(),
          ),
          ListTile(
            leading: lib.isBulkScanningMetadata
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_sync_outlined),
            title: const Text('Scan Metadata yang Belum Ada'),
            subtitle: Text(lib.isBulkScanningMetadata
                ? 'Memproses ${lib.bulkScanProgress}/${lib.bulkScanTotal}...'
                : 'Ambil judul/artis/cover/lirik dari internet, khusus lagu yang belum pernah discan'),
            onTap: lib.isBulkScanningMetadata ? null : () => lib.bulkScanMetadata(onlyMissing: true),
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Scan Ulang Semua Metadata'),
            subtitle: const Text('Ambil ulang dari internet untuk SEMUA lagu, meski sudah pernah discan sebelumnya'),
            onTap: lib.isBulkScanningMetadata
                ? null
                : () => showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Scan Ulang Semua'),
                        content: Text('Ambil ulang metadata untuk semua ${lib.totalCount} lagu dari internet? Ini butuh waktu lebih lama dibanding scan yang belum ada saja.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                          FilledButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              lib.bulkScanMetadata(onlyMissing: false);
                            },
                            child: const Text('Mulai'),
                          ),
                        ],
                      ),
                    ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('Pemutaran', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          SwitchListTile(
            title: const Text('Crossfade'),
            subtitle: const Text('Transisi antar lagu tanpa jeda (3 detik)'),
            value: PlayerService.instance.crossfadeEnabled,
            onChanged: (v) => setState(() => PlayerService.instance.setCrossfadeEnabled(v)),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('Tentang', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          const ListTile(
            title: Text('Swara'),
            subtitle: Text('v1.5.0'),
          ),
        ],
      ),
    );
  }
}
