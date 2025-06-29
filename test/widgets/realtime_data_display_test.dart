import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:js_dash/widgets/realtime_data_display.dart';
import 'package:js_dash/services/mavlink_service.dart';
import 'package:js_dash/services/mavlink_spoof_service.dart';
import 'package:js_dash/services/mavlink_message_tracker.dart';

void main() {
  group('RealtimeDataDisplay Widget', () {
    setUpAll(() {
      // Reset any singleton state before widget tests
      MavlinkService.resetInstanceForTesting();
      MavlinkSpoofService.resetInstanceForTesting();
      MavlinkMessageTracker.resetInstanceForTesting();
    });
    
    tearDownAll(() {
      // Clean up after all widget tests
      MavlinkService.resetInstanceForTesting();
      MavlinkSpoofService.resetInstanceForTesting();
      MavlinkMessageTracker.resetInstanceForTesting();
    });

    testWidgets('should build without error', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RealtimeDataDisplay(autoStartMonitor: false),
        ),
      );

      expect(find.byType(RealtimeDataDisplay), findsOneWidget);
    });

    testWidgets('should show app bar with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RealtimeDataDisplay(autoStartMonitor: false),
        ),
      );

      expect(find.text('Submersible Jetski Dashboard'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('should have basic UI structure', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RealtimeDataDisplay(autoStartMonitor: false),
        ),
      );

      await tester.pump();

      // Should have app bar
      expect(find.byType(AppBar), findsOneWidget);
      
      // Should have at least one scaffold
      expect(find.byType(Scaffold), findsOneWidget);
      
      // Should have padding container
      expect(find.byType(Padding), findsAtLeastNWidgets(1));
    });
  });
}