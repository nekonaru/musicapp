import 'package:equalizer_flutter/equalizer_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Resample a 5-band EQ curve to [bandCount] device bands.
///
/// Pure linear interpolation so it is unit testable. [curve] holds
/// relative dB gains from the lowest to the highest band.
List<double> resampleCurve(List<double> curve, int bandCount) {
  if (curve.isEmpty || bandCount <= 0) return List.filled(bandCount, 0);
  if (bandCount == 1) {
    final avg = curve.reduce((a, b) => a + b) / curve.length;
    return [avg];
  }
  final out = <double>[];
  for (int i = 0; i < bandCount; i++) {
    final pos = i * (curve.length - 1) / (bandCount - 1);
    final lo = pos.floor().clamp(0, curve.length - 1);
    final hi = pos.ceil().clamp(0, curve.length - 1);
    final frac = pos - lo;
    out.add(curve[lo] * (1 - frac) + curve[hi] * frac);
  }
  return out;
}

/// Canonical 5-band curves (relative dB, low to high).
/// Must stay in sync with the EQ preset UI choices.
const Map<String, List<double>> kEqCurves = {
  'Flat': [0, 0, 0, 0, 0],
  'Pop': [1, 2, 2, 1, 0],
  'Rock': [3, 1, -1, 1, 3],
  'Classical': [2, 0, 0, 0, 2],
  'Jazz': [2, 1, 0, 1, 2],
  'Electronic': [3, 1, 0, 2, 3],
  'Hip-Hop': [3, 2, 0, 0, 1],
  'Bass Boost': [4, 3, 0, 0, 0],
  'Vocal': [-1, 0, 2, 2, 0],
  'Custom': [0, 0, 0, 0, 0],
};

/// Drives the Android system equalizer for the active audio session.
///
/// The effect is real DSP on the output mix, not a visualizer. The
/// underlying plugin is old and can hang on some devices, so EVERY
/// platform call goes through [_guard] with a timeout: a stuck call
/// degrades to flat sound instead of freezing the settings screen.
class EqualizerService {
  EqualizerService._();
  static final EqualizerService instance = EqualizerService._();

  /// A plugin call taking longer than this is treated as failed.
  /// Without this, one stuck method-channel call freezes preset
  /// switching until the settings screen is reopened.
  static const Duration _pluginTimeout = Duration(milliseconds: 2500);

  int? _sessionId;
  bool _ready = false;
  String _preset = 'Flat';
  // Live gains for the Custom preset, set via applyCustom.
  List<double> _customGains = [0, 0, 0, 0, 0];

  String get preset => _preset;
  bool get isReady => _ready;

  Future<bool> _run(Future<void> Function() op, String what) async {
    try {
      await op().timeout(_pluginTimeout);
      return true;
    } catch (e) {
      debugPrint('Equalizer $what failed: $e');
      return false;
    }
  }

  Future<List<int>?> _getList(
      Future<List<int>> Function() op, String what) async {
    try {
      return await op().timeout(_pluginTimeout);
    } catch (e) {
      debugPrint('Equalizer $what failed: $e');
      return null;
    }
  }

  /// Attach the effect to [player]'s audio session. Call after the
  /// player has a source (session id is null before that).
  /// Returns true when the effect is attached.
  Future<bool> attach(AudioPlayer player) async {
    final sessionId = player.androidAudioSessionId;
    if (sessionId == null) return false;
    if (_ready && sessionId == _sessionId) {
      await _applyBands();
      return true;
    }
    await release();
    final attached =
        await _run(() => EqualizerFlutter.init(sessionId), 'init');
    if (!attached) {
      _ready = false;
      _sessionId = null;
      return false;
    }
    _sessionId = sessionId;
    _ready = true;
    await _applyBands();
    return true;
  }

  /// Switch preset (persisted separately by ThemeProvider).
  Future<void> applyPreset(String name) async {
    _preset = name;
    if (!_ready) return;
    await _applyBands();
  }

  /// Apply user slider gains as the Custom preset. Always treated as a
  /// non Flat preset (effect enabled, resampled, bands set).
  Future<void> applyCustom(List<double> gains) async {
    _preset = 'Custom';
    _customGains = List<double>.generate(
        5, (i) => i < gains.length ? gains[i] : 0.0);
    if (!_ready) return;
    await _applyBands();
  }

  Future<void> _applyBands() async {
    if (_preset == 'Flat') {
      await _run(() => EqualizerFlutter.setEnabled(false), 'disable');
      return;
    }
    await _run(() => EqualizerFlutter.setEnabled(true), 'enable');
    final List<double> curve;
    if (_preset == 'Custom') {
      curve = List.of(_customGains);
    } else {
      curve = kEqCurves[_preset] ?? kEqCurves['Flat']!;
    }
    var bandCount = 5;
    var minMb = -1500;
    var maxMb = 1500;
    final range =
        await _getList(() => EqualizerFlutter.getBandLevelRange(), 'range');
    if (range != null && range.length >= 2) {
      minMb = range[0];
      maxMb = range[1];
    }
    final freqs = await _getList(
        () => EqualizerFlutter.getCenterBandFreqs(), 'freqs');
    if (freqs != null && freqs.isNotEmpty) bandCount = freqs.length;
    final gains = resampleCurve(curve, bandCount);
    for (int i = 0; i < bandCount; i++) {
      // Curve values are relative dB. NOTE: this old plugin divides the
      // Android millibel range by 100 on read, but setBandLevel still
      // takes raw millibels, so scale both sides back up here.
      final mb =
          (gains[i] * 100).round().clamp(minMb * 100, maxMb * 100);
      await _run(() => EqualizerFlutter.setBandLevel(i, mb), 'band $i');
    }
  }

  Future<void> release() async {
    if (!_ready) return;
    await _run(() => EqualizerFlutter.release(), 'release');
    _ready = false;
    _sessionId = null;
  }
}
