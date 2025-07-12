import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:js_dash/views/telemetry/mavlink_message_monitor.dart';

void main() {
  group('MavlinkMessageMonitor Basic Tests', () {
    testWidgets('should build and display basic structure', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MavlinkMessageMonitor(autoStart: false),
            ),
          ),
        ),
      );

      // Basic structure tests that don't depend on timers
      expect(find.text('Monitor'), findsOneWidget);
      expect(find.byIcon(Icons.monitor), findsOneWidget);
      expect(find.text('No Messages'), findsOneWidget);
      expect(find.text('Waiting for MAVLink data...'), findsOneWidget);
      
      // Just pump once to render, don't wait for settle
      await tester.pump();
    });
  });
}