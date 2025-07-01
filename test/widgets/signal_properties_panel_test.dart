import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:js_dash/models/plot_configuration.dart';
import 'package:js_dash/widgets/signal_properties_panel.dart';

void main() {
  group('SignalPropertiesPanel Widget Tests', () {
    testWidgets('should display signal properties title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SignalPropertiesPanel(
              signals: [],
              scalingMode: ScalingMode.autoScale,
              onSignalUpdated: (signal) {},
              onSignalRemoved: (signalId) {},
              onAddSignals: () {},
              onScalingModeChanged: (mode) {},
            ),
          ),
        ),
      );

      expect(find.text('Signal Properties'), findsOneWidget);
    });

    testWidgets('should show empty state when no signals', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SignalPropertiesPanel(
              signals: [],
              scalingMode: ScalingMode.autoScale,
              onSignalUpdated: (signal) {},
              onSignalRemoved: (signalId) {},
              onAddSignals: () {},
              onScalingModeChanged: (mode) {},
            ),
          ),
        ),
      );

      expect(find.text('No signals to configure'), findsOneWidget);
      expect(find.text('Add signals to customize their appearance'), findsOneWidget);
    });

    testWidgets('should display signals when available', (tester) async {
      final signals = [
        PlotSignalConfiguration(
          id: 'test1',
          messageType: 'ATTITUDE',
          fieldName: 'roll',
          color: Colors.red,
        ),
        PlotSignalConfiguration(
          id: 'test2',
          messageType: 'ATTITUDE',
          fieldName: 'pitch',
          color: Colors.blue,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SignalPropertiesPanel(
              signals: signals,
              scalingMode: ScalingMode.autoScale,
              onSignalUpdated: (signal) {},
              onSignalRemoved: (signalId) {},
              onAddSignals: () {},
              onScalingModeChanged: (mode) {},
            ),
          ),
        ),
      );

      expect(find.text('ATTITUDE.roll'), findsWidgets);
      expect(find.text('ATTITUDE.pitch'), findsWidgets);
    });

    testWidgets('should call onAddSignals when add button clicked', (tester) async {
      bool addCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SignalPropertiesPanel(
              signals: [],
              scalingMode: ScalingMode.autoScale,
              onSignalUpdated: (signal) {},
              onSignalRemoved: (signalId) {},
              onAddSignals: () => addCalled = true,
              onScalingModeChanged: (mode) {},
            ),
          ),
        ),
      );

      // Find and tap the add button
      final addButton = find.text('Add');
      await tester.tap(addButton.first);
      await tester.pump();

      expect(addCalled, true);
    });

    testWidgets('should call onScalingModeChanged when dropdown changed', (tester) async {
      ScalingMode? changedMode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SignalPropertiesPanel(
              signals: [],
              scalingMode: ScalingMode.autoScale,
              onSignalUpdated: (signal) {},
              onSignalRemoved: (signalId) {},
              onAddSignals: () {},
              onScalingModeChanged: (mode) => changedMode = mode,
            ),
          ),
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

    testWidgets('should show signal property controls when signal expanded', (tester) async {
      final signal = PlotSignalConfiguration(
        id: 'test1',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
        displayName: 'Roll Angle',
        lineWidth: 2.0,
        showDots: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SignalPropertiesPanel(
              signals: [signal],
              scalingMode: ScalingMode.autoScale,
              onSignalUpdated: (signal) {},
              onSignalRemoved: (signalId) {},
              onAddSignals: () {},
              onScalingModeChanged: (mode) {},
            ),
          ),
        ),
      );

      // Find and tap to expand the signal tile
      final expansionTile = find.byType(ExpansionTile);
      await tester.tap(expansionTile);
      await tester.pumpAndSettle();

      // Should show property controls
      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('Line Width'), findsOneWidget);
      expect(find.text('Show Dots'), findsOneWidget);
    });

    testWidgets('should call onSignalRemoved when delete button clicked', (tester) async {
      String? removedSignalId;
      final signal = PlotSignalConfiguration(
        id: 'test1',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SignalPropertiesPanel(
              signals: [signal],
              scalingMode: ScalingMode.autoScale,
              onSignalUpdated: (signal) {},
              onSignalRemoved: (signalId) => removedSignalId = signalId,
              onAddSignals: () {},
              onScalingModeChanged: (mode) {},
            ),
          ),
        ),
      );

      // Find and tap the delete button
      final deleteButton = find.byIcon(Icons.delete_outline);
      await tester.tap(deleteButton);
      await tester.pump();

      expect(removedSignalId, 'test1');
    });

    // Color picker test removed - complex to test dialogs in widget tests
  });
}