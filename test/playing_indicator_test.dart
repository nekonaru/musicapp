import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swara/widgets/playing_indicator.dart';

// Helper to build the widget inside a MaterialApp wrapper.
Widget buildIndicator({required bool isPlaying}) {
  return MaterialApp(
    home: Scaffold(
      body: PlayingIndicator(
        isPlaying: isPlaying,
        color: Colors.green,
      ),
    ),
  );
}

void main() {
  // Idle state must render without starting any animation.
  testWidgets('renders without error when isPlaying is false',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildIndicator(isPlaying: false));

    // The indicator and its three bars should be present.
    expect(find.byType(PlayingIndicator), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PlayingIndicator),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNWidgets(3),
    );

    // Pumping another frame must not throw since nothing animates.
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  // Active state must render and run the bar animations.
  testWidgets('renders and animates when isPlaying is true',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildIndicator(isPlaying: true));

    expect(find.byType(PlayingIndicator), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PlayingIndicator),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNWidgets(3),
    );

    // Advance time so the repeating controllers tick forward.
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  // Toggling from playing to idle must stop cleanly without errors.
  testWidgets('updates from true to false without error',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildIndicator(isPlaying: true));
    await tester.pump(const Duration(milliseconds: 200));

    // Rebuild with playback stopped.
    await tester.pumpWidget(buildIndicator(isPlaying: false));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(PlayingIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
