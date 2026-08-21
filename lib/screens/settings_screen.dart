import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
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
            subtitle: Text('v1.4.0'),
          ),
        ],
      ),
    );
  }
}
