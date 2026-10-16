import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<Color> kAccentColors = [
  Color(0xFF6750A4), // Deep Purple (default)
  Color(0xFF0066CC), // Blue
  Color(0xFF00897B), // Teal
  Color(0xFF2E7D32), // Green
  Color(0xFFE65100), // Orange
  Color(0xFFC62828), // Red
  Color(0xFF6A1B9A), // Purple
  Color(0xFFAD1457), // Pink
  Color(0xFF00838F), // Cyan
  Color(0xFF558B2F), // Light Green
];

const List<String> kAccentColorNames = [
  'Ungu',
  'Biru',
  'Teal',
  'Hijau',
  'Oranye',
  'Merah',
  'Ungu Tua',
  'Pink',
  'Cyan',
  'Hijau Muda',
];

// Allowed app text scale factors shown in Settings.
const List<double> kTextScales = [0.85, 1.0, 1.15, 1.3];

class ThemeProvider extends ChangeNotifier {
  static const _prefsKey = 'themeMode';
  static const _accentKey = 'accentColorIndex';
  static const _equalizerPresetKey = 'equalizerPreset';
  static const _textScaleKey = 'textScale';
  static const _customEqGainsKey = 'custom_eq_gains';
  static const _amoledBlackKey = 'amoledBlack';

  ThemeMode themeMode = ThemeMode.dark;
  int accentColorIndex = 0;
  String equalizerPreset = 'Flat';
  // App text scale factor. Applied to MediaQuery by another workstream.
  double textScale = 1.0;
  // Custom 5-band EQ gains (low to high). Used only with the Custom preset.
  List<double> customEqGains = [0, 0, 0, 0, 0];
  // Pitch black background for the dark theme. Wired in main by someone else.
  bool amoledBlack = false;

  Color get accentColor => kAccentColors[accentColorIndex];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null) {
      themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => ThemeMode.dark,
      );
    }
    accentColorIndex = (prefs.getInt(_accentKey) ?? 0)
        .clamp(0, kAccentColors.length - 1);
    equalizerPreset = prefs.getString(_equalizerPresetKey) ?? 'Flat';
    // Fall back to 1.0 when nothing is stored or the stored value is unknown.
    final savedScale = prefs.getDouble(_textScaleKey) ?? 1.0;
    textScale = kTextScales.contains(savedScale) ? savedScale : 1.0;
    customEqGains = _readCustomGains(prefs);
    amoledBlack = prefs.getBool(_amoledBlackKey) ?? false;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }

  Future<void> setAccentColor(int index) async {
    accentColorIndex = index.clamp(0, kAccentColors.length - 1);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, accentColorIndex);
  }

  Future<void> setEqualizerPreset(String preset) async {
    equalizerPreset = preset;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_equalizerPresetKey, preset);
  }

  // Persist the selected text scale and notify listeners at once.
  Future<void> setTextScale(double scale) async {
    textScale = scale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_textScaleKey, scale);
  }

  // Read the stored custom gains, falling back to flat on bad data.
  static List<double> _readCustomGains(SharedPreferences prefs) {
    const flat = [0.0, 0.0, 0.0, 0.0, 0.0];
    final stored = prefs.getStringList(_customEqGainsKey);
    if (stored == null || stored.length != 5) return List.of(flat);
    try {
      return stored.map(double.parse).toList();
    } catch (_) {
      return List.of(flat);
    }
  }

  // Save the Custom preset slider values and notify listeners at once.
  Future<void> setCustomEqGains(List<double> gains) async {
    final fixed = List<double>.generate(
        5, (i) => i < gains.length ? gains[i].clamp(-6.0, 6.0) : 0.0);
    customEqGains = fixed;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _customEqGainsKey, fixed.map((g) => g.toString()).toList());
  }

  // Toggle the pitch black dark theme variant and persist it.
  Future<void> setAmoledBlack(bool value) async {
    amoledBlack = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_amoledBlackKey, value);
  }

  // Dark theme for main to use. Returns the plain dark theme normally,
  // or a pitch black variant when amoledBlack is on. Same seed either way.
  ThemeData buildDarkTheme() {
    final base = ThemeData(
      colorSchemeSeed: accentColor,
      brightness: Brightness.dark,
      useMaterial3: true,
    );
    if (!amoledBlack) return base;
    final scheme = base.colorScheme.copyWith(
      surface: Colors.black,
    );
    return base.copyWith(
      scaffoldBackgroundColor: Colors.black,
      canvasColor: Colors.black,
      cardColor: Colors.black,
      colorScheme: scheme,
    );
  }
}
