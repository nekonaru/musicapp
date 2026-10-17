import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the localization contract:
/// every message key in app_en.arb must exist in app_id.arb with the same
/// placeholder set. A missing Indonesian entry silently falls back to
/// English at runtime, and a missing placeholder would throw on format.
void main() {
  Map<String, dynamic> _loadArb(String name) {
    final file = File('lib/l10n/$name.arb');
    expect(file.existsSync(), isTrue, reason: 'missing $name.arb');
    return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  Set<String> _placeholderNames(Map<String, dynamic> metadata, String key) {
    final meta = metadata['@$key'];
    if (meta is! Map) return const {};
    final placeholders = meta['placeholders'];
    if (placeholders is! Map) return const {};
    return placeholders.keys.map((k) => k.toString()).toSet();
  }

  Set<String> _messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  test('app_id.arb has every message key from app_en.arb', () {
    final en = _loadArb('app_en');
    final id = _loadArb('app_id');
    final enKeys = _messageKeys(en);
    final idKeys = _messageKeys(id);
    final missing = enKeys.where((k) => !idKeys.contains(k)).toSet();
    expect(
      missing,
      isEmpty,
      reason: 'Indonesian translation missing for: ${missing.join(', ')}',
    );
  });

  test('no extra message key in app_id.arb', () {
    final en = _loadArb('app_en');
    final id = _loadArb('app_id');
    final extra = _messageKeys(id).difference(_messageKeys(en));
    expect(
      extra,
      isEmpty,
      reason: 'Indonesian has keys absent from English: ${extra.join(', ')}',
    );
  });

  test('placeholder sets match between English and Indonesian', () {
    final en = _loadArb('app_en');
    final id = _loadArb('app_id');
    final mismatched = <String>[];
    for (final key in _messageKeys(en)) {
      final enPlaceholders = _placeholderNames(en, key);
      final idPlaceholders = _placeholderNames(id, key);
      if (enPlaceholders.length != idPlaceholders.length ||
          !enPlaceholders.containsAll(idPlaceholders)) {
        mismatched.add(key);
      }
    }
    expect(
      mismatched,
      isEmpty,
      reason: 'placeholder mismatch on: ${mismatched.join(', ')}',
    );
  });

  test('every placeholder appears in its English message', () {
    final en = _loadArb('app_en');
    final missing = <String>[];
    for (final key in _messageKeys(en)) {
      final message = en[key];
      if (message is! String) continue;
      for (final placeholder in _placeholderNames(en, key)) {
        if (!message.contains('{$placeholder}')) missing.add('$key/$placeholder');
      }
    }
    expect(
      missing,
      isEmpty,
      reason: 'placeholder not used in message: ${missing.join(', ')}',
    );
  });
}