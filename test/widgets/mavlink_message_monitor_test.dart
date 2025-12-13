import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:js_dash/mavlink/mavlink.dart';
import 'package:js_dash/models/statustext_entry.dart';
import 'package:js_dash/views/telemetry/mavlink_message_monitor.dart';
import 'package:js_dash/services/generic_message_tracker.dart';
import 'package:js_dash/services/settings_manager.dart';
import 'package:js_dash/services/timeseries_data_manager.dart';
import 'package:js_dash/providers/service_providers.dart';
import 'package:js_dash/providers/statustext_provider.dart';

/// Test notifier that provides empty status text without requiring connection manager
class _TestStatusTextNotifier extends Notifier<List<StatusTextEntry>>
    implements StatusTextNotifier {
  @override
  List<StatusTextEntry> build() => [];

  @override
  void clear() {
    state = [];
  }
}

void main() {
  group('MavlinkMessageMonitor Widget', () {
    late MavlinkMetadataRegistry registry;
    late GenericMessageTracker tracker;
    late SettingsManager settingsManager;
    late TimeSeriesDataManager dataManager;

    setUp(() {
      registry = MavlinkMetadataRegistry();
      registry.loadFromJsonString('''
{
  "schema_version": "1.0.0",
  "enums": {},
  "messages": {
    "0": {
      "id": 0,
      "name": "HEARTBEAT",
      "description": "Heartbeat",
      "crc_extra": 50,
      "encoded_length": 9,
      "fields": []
    }
  }
}
''');
      tracker = GenericMessageTracker(registry);
      tracker.startTracking();
      settingsManager = SettingsManager();
      dataManager = TimeSeriesDataManager.injected(tracker, settingsManager);
    });

    tearDown(() {
      tracker.stopTracking();
      dataManager.dispose();
    });

    /// Get provider overrides for testing
    getTestOverrides() => [
      mavlinkRegistryProvider.overrideWith((ref) => registry),
      messageTrackerProvider.overrideWith((ref) => tracker),
      timeSeriesDataManagerProvider.overrideWith((ref) => dataManager),
      // Override the notifier directly for testing
      statusTextProvider.overrideWith(_TestStatusTextNotifier.new),
    ];

    testWidgets('should build without error', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getTestOverrides(),
          child: MaterialApp(
            home: Scaffold(body: MavlinkMessageMonitor(autoStart: false)),
          ),
        ),
      );

      expect(find.byType(MavlinkMessageMonitor), findsOneWidget);
      await tester.pump();
    });

    testWidgets('should show header with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getTestOverrides(),
          child: MaterialApp(
            home: Scaffold(
              body: MavlinkMessageMonitor(
                autoStart: false,
                header: Row(
                  children: const [
                    Icon(Icons.monitor),
                    Text('Monitor'),
                    Icon(Icons.clear_all),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Monitor'), findsOneWidget);
      expect(find.byIcon(Icons.monitor), findsOneWidget);
      expect(find.byIcon(Icons.clear_all), findsOneWidget);

      await tester.pump();
    });

    testWidgets('should show empty state when no messages', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getTestOverrides(),
          child: MaterialApp(
            home: Scaffold(body: MavlinkMessageMonitor(autoStart: false)),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('No Messages'), findsOneWidget);
      expect(find.text('Waiting for MAVLink data...'), findsOneWidget);
      expect(find.byIcon(Icons.radio), findsOneWidget);

      await tester.pump();
    });

    testWidgets('should have container widgets', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getTestOverrides(),
          child: MaterialApp(
            home: Scaffold(body: MavlinkMessageMonitor(autoStart: false)),
          ),
        ),
      );

      // Should have containers for layout
      expect(find.byType(Container), findsAtLeastNWidgets(1));

      await tester.pump();
    });

    testWidgets('should show clear button in header', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getTestOverrides(),
          child: MaterialApp(
            home: Scaffold(
              body: MavlinkMessageMonitor(
                autoStart: false,
                header: IconButton(
                  icon: const Icon(Icons.clear_all),
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );

      final clearButton = find.byIcon(Icons.clear_all);
      expect(clearButton, findsOneWidget);

      // Verify button is tappable
      await tester.tap(clearButton);
      await tester.pump();
    });

    testWidgets('should have proper visual structure', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: getTestOverrides(),
          child: MaterialApp(
            home: Scaffold(
              body: MavlinkMessageMonitor(
                autoStart: false,
                header: const Text('Monitor'),
              ),
            ),
          ),
        ),
      );

      // Should have main container
      expect(find.byType(Container), findsAtLeastNWidgets(1));

      // Should have column layout
      expect(find.byType(Column), findsAtLeastNWidgets(1));

      // Should have header section
      expect(find.text('Monitor'), findsOneWidget);

      // Should have expandable body section
      expect(find.byType(Expanded), findsAtLeastNWidgets(1));

      await tester.pump();
    });
  });
}
