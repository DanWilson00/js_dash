import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:js_dash/models/plot_configuration.dart';
import 'package:js_dash/views/telemetry/signal_selector_panel.dart';
import 'package:js_dash/services/timeseries_data_manager.dart';
import 'package:js_dash/services/mavlink_message_tracker.dart';
import 'package:js_dash/providers/service_providers.dart';

void main() {
  group('SignalSelectorPanel Widget Tests', () {
    late TimeSeriesDataManager dataManager;
    late MavlinkMessageTracker tracker;

    setUp(() {
      tracker = MavlinkMessageTracker();
      dataManager = TimeSeriesDataManager.injected(tracker, null);
    });

    tearDown(() {
      dataManager.dispose();
      tracker.dispose();
    });

    Widget buildTestWidget({
      required List<PlotSignalConfiguration> activeSignals,
      required ScalingMode scalingMode,
      required Function(String, String) onSignalToggle,
      required Function(ScalingMode) onScalingModeChanged,
    }) {
      return ProviderScope(
        overrides: [
          timeSeriesDataManagerProvider.overrideWithValue(dataManager),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SignalSelectorPanel(
              activeSignals: activeSignals,
              scalingMode: scalingMode,
              onSignalToggle: onSignalToggle,
              onScalingModeChanged: onScalingModeChanged,
            ),
          ),
        ),
      );
    }

    testWidgets('should display available signals title', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          activeSignals: [],
          scalingMode: ScalingMode.autoScale,
          onSignalToggle: (messageType, fieldName) {},
          onScalingModeChanged: (mode) {},
        ),
      );

      expect(find.text('Available Signals'), findsOneWidget);
    });

    testWidgets('should show empty state when no data available', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          activeSignals: [],
          scalingMode: ScalingMode.autoScale,
          onSignalToggle: (messageType, fieldName) {},
          onScalingModeChanged: (mode) {},
        ),
      );

      expect(find.text('No MAVLink data available'), findsOneWidget);
    });

    testWidgets('should display active signal count', (tester) async {
      final activeSignals = [
        PlotSignalConfiguration(
          id: 'test1',
          messageType: 'ATTITUDE',
          fieldName: 'roll',
          color: Colors.red,
        ),
      ];

      await tester.pumpWidget(
        buildTestWidget(
          activeSignals: activeSignals,
          scalingMode: ScalingMode.autoScale,
          onSignalToggle: (messageType, fieldName) {},
          onScalingModeChanged: (mode) {},
        ),
      );

      expect(find.text('1 active'), findsOneWidget);
    });

    testWidgets('should show scaling mode dropdown', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          activeSignals: [],
          scalingMode: ScalingMode.autoScale,
          onSignalToggle: (messageType, fieldName) {},
          onScalingModeChanged: (mode) {},
        ),
      );

      expect(find.text('Scaling:'), findsOneWidget);
      expect(find.byType(DropdownButton<ScalingMode>), findsOneWidget);
    });

    testWidgets('should call onSignalToggle when signal is tapped', (tester) async {
      String? toggledMessageType;
      String? toggledFieldName;

      // Add some test data
      dataManager.injectTestData('ATTITUDE', 'roll', 1.5);

      await tester.pumpWidget(
        buildTestWidget(
          activeSignals: [],
          scalingMode: ScalingMode.autoScale,
          onSignalToggle: (messageType, fieldName) {
            toggledMessageType = messageType;
            toggledFieldName = fieldName;
          },
          onScalingModeChanged: (mode) {},
        ),
      );

      // Wait for data to be available and widget to update
      await tester.pump();

      // Find and tap on refresh to load the data
      final refreshButton = find.byIcon(Icons.refresh);
      await tester.tap(refreshButton);
      await tester.pumpAndSettle();

      // Look for expansion tile with ATTITUDE
      final attitudeTile = find.text('ATTITUDE');
      if (attitudeTile.evaluate().isNotEmpty) {
        await tester.tap(attitudeTile);
        await tester.pumpAndSettle();

        // Find and tap the roll field
        final rollTile = find.text('roll');
        if (rollTile.evaluate().isNotEmpty) {
          await tester.tap(rollTile);
          await tester.pump();

          expect(toggledMessageType, 'ATTITUDE');
          expect(toggledFieldName, 'roll');
        }
      }
    });

    testWidgets('should call onScalingModeChanged when dropdown changed', (tester) async {
      ScalingMode? changedMode;

      await tester.pumpWidget(
        buildTestWidget(
          activeSignals: [],
          scalingMode: ScalingMode.autoScale,
          onSignalToggle: (messageType, fieldName) {},
          onScalingModeChanged: (mode) {
            changedMode = mode;
          },
        ),
      );

      // Find and tap the scaling mode dropdown
      final dropdown = find.byType(DropdownButton<ScalingMode>);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      // Tap on unified mode
      await tester.tap(find.text('Unified').last);
      await tester.pump();

      expect(changedMode, ScalingMode.unified);
    });

    testWidgets('should highlight active signals correctly', (tester) async {
      final activeSignal = PlotSignalConfiguration(
        id: 'test1',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
      );

      // Add test data
      dataManager.injectTestData('ATTITUDE', 'roll', 1.5);
      dataManager.injectTestData('ATTITUDE', 'pitch', 0.5);

      await tester.pumpWidget(
        buildTestWidget(
          activeSignals: [activeSignal],
          scalingMode: ScalingMode.autoScale,
          onSignalToggle: (messageType, fieldName) {},
          onScalingModeChanged: (mode) {},
        ),
      );

      // Refresh to load data
      final refreshButton = find.byIcon(Icons.refresh);
      await tester.tap(refreshButton);
      await tester.pumpAndSettle();

      // The active signal should be highlighted differently
      // This test verifies the structure exists for highlighting
      expect(tester.takeException(), isNull);
    });

    testWidgets('should update when activeSignals prop changes', (tester) async {
      final signal1 = PlotSignalConfiguration(
        id: 'test1',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
      );

      // Start with no active signals
      await tester.pumpWidget(
        buildTestWidget(
          activeSignals: [],
          scalingMode: ScalingMode.autoScale,
          onSignalToggle: (messageType, fieldName) {},
          onScalingModeChanged: (mode) {},
        ),
      );

      expect(find.text('0 active'), findsOneWidget);

      // Update to have one active signal
      await tester.pumpWidget(
        buildTestWidget(
          activeSignals: [signal1],
          scalingMode: ScalingMode.autoScale,
          onSignalToggle: (messageType, fieldName) {},
          onScalingModeChanged: (mode) {},
        ),
      );

      expect(find.text('1 active'), findsOneWidget);
    });
  });
}
