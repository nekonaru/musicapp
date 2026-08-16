import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
            child: Text('Tentang', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          const ListTile(
            title: Text('Swara'),
            subtitle: Text('v1.1.0'),
          ),
        ],
      ),
    );
  }
}
