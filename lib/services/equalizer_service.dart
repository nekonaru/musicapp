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
};

/// Drives the Android system equalizer for the active audio session.
///
/// The effect is real DSP on the output mix, not a visualizer. Every
/// platform call is guarded so devices without an equalizer simply
/// keep playing with a flat response.
class EqualizerService {
  EqualizerService._();
  static final EqualizerService instance = EqualizerService._();

  int? _sessionId;
  bool _ready = false;
  String _preset = 'Flat';

  String get preset => _preset;
  bool get isReady => _ready;

  /// Attach the effect to [player]'s audio session. Call after the
  /// player has a source (session id is null before that).
  /// Returns true when the effect is attached.
  Future<bool> attach(AudioPlayer player) async {
    try {
      final sessionId = player.androidAudioSessionId;
      if (sessionId == null) return false;
      if (_ready && sessionId == _sessionId) {
        await _applyBands();
        return true;
      }
      await release();
      EqualizerFlutter.init(sessionId);
      _sessionId = sessionId;
      _ready = true;
      await _applyBands();
      return true;
    } catch (e) {
      debugPrint('Equalizer attach failed: $e');
      _ready = false;
      _sessionId = null;
      return false;
    }
  }

  /// Switch preset (persisted separately by ThemeProvider).
  Future<void> applyPreset(String name) async {
    _preset = name;
    if (!_ready) return;
    await _applyBands();
  }

  Future<void> _applyBands() async {
    try {
      if (_preset == 'Flat') {
        await EqualizerFlutter.setEnabled(false);
        return;
      }
      await EqualizerFlutter.setEnabled(true);
      final curve = kEqCurves[_preset] ?? kEqCurves['Flat']!;
      var bandCount = 5;
      var minMb = -1500;
      var maxMb = 1500;
      try {
        final range = await EqualizerFlutter.getBandLevelRange();
        if (range.length >= 2) {
          minMb = range[0];
          maxMb = range[1];
        }
      } catch (_) {
        // Keep safe defaults when the device hides the range.
      }
      try {
        final freqs = await EqualizerFlutter.getCenterBandFreqs();
        if (freqs.isNotEmpty) bandCount = freqs.length;
      } catch (_) {
        // Keep the 5-band default.
      }
      final gains = resampleCurve(curve, bandCount);
      for (int i = 0; i < bandCount; i++) {
        // Curve values are relative dB, device levels are millibels.
        final mb = (gains[i] * 300).round().clamp(minMb, maxMb);
        await EqualizerFlutter.setBandLevel(i, mb);
      }
    } catch (e) {
      debugPrint('Equalizer apply failed: $e');
    }
  }

  Future<void> release() async {
    if (!_ready) return;
    try {
      await EqualizerFlutter.release();
    } catch (e) {
      debugPrint('Equalizer release failed: $e');
    }
    _ready = false;
    _sessionId = null;
  }
}
