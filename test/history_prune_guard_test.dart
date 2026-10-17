import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression guard for a real data loss bug shipped in v2.6.0.
///
/// The listening history prune was run automatically from onCreate and
/// onUpgrade. Two things went wrong at once:
///  1. The dashboard totals (Total listened, Top songs, Top artists,
///     listening hours) are computed from listening_entries with no date
///     filter, so deleting rows silently rewrote numbers the user sees.
///  2. Statements sent while the migration transaction is open join that
///     transaction, so the prune blocked the database open instead of
///     running in the background as the comment claimed.
///
/// The prune is now user triggered from Settings, so db_helper must never
/// call it on its own.
void main() {
  test('db_helper never triggers the history prune by itself', () {
    final source =
        File('lib/services/db_helper.dart').readAsStringSync();
    expect(
      source.contains('unawaited(_prune'),
      isFalse,
      reason: 'the prune must not run during database open or upgrade',
    );

    // The only remaining reference may be the public declaration itself.
    final calls = RegExp(r'(?<!Future<int> )pruneListeningEntries\(')
        .allMatches(source)
        .length;
    expect(
      calls,
      lessThanOrEqualTo(1),
      reason: 'pruneListeningEntries must only be declared, never called '
          'inside db_helper',
    );
  });

  test('the prune age comparison does not rely on raw string ordering', () {
    final source = File('lib/services/db_helper.dart').readAsStringSync();
    // A lexicographic comparison silently deletes fresh rows whose
    // timestamp came from a restored backup with an offset or a short form.
    expect(
      source.contains("where: 'timestamp < ?'"),
      isFalse,
      reason: 'timestamp must be compared through julianday()',
    );
    expect(source.contains('julianday(timestamp)'), isTrue);
  });
}