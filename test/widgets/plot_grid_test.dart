import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:js_dash/views/telemetry/plot_grid.dart';
import 'package:js_dash/services/timeseries_data_manager.dart';
import 'package:js_dash/services/settings_manager.dart';
import 'package:js_dash/models/plot_configuration.dart';

void main() {
  group('PlotGridManager Basic Tests', () {
    late SettingsManager settingsManager;
    
    setUp(() {
      TimeSeriesDataManager.resetInstanceForTesting();
      settingsManager = SettingsManager();
    });

    tearDown(() {
      TimeSeriesDataManager.resetInstanceForTesting();
    });

    testWidgets('should build and display basic structure', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlotGridManager(settingsManager: settingsManager),
          ),
        ),
      );

      // Basic structure tests
      expect(find.text('Plots:'), findsOneWidget);
      expect(find.text('Layout:'), findsOneWidget);
      expect(find.byType(DropdownButton<int>), findsOneWidget);
      
      // Just pump once to render
      await tester.pump();
    });

    testWidgets('should show single plot by default', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlotGridManager(settingsManager: settingsManager),
          ),
        ),
      );

      await tester.pump();

      // Should have at least one plot widget
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('should show plot count dropdown options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlotGridManager(settingsManager: settingsManager),
          ),
        ),
      );

      // Find and tap the plot count dropdown
      final plotCountDropdown = find.byType(DropdownButton<int>);
      expect(plotCountDropdown, findsOneWidget);

      await tester.tap(plotCountDropdown);
      await tester.pumpAndSettle();

      // Should show options 1-6 (multiple instances expected due to current selection)
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('should auto-select first plot', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlotGridManager(settingsManager: settingsManager),
          ),
        ),
      );

      await tester.pump();

      // Should show "Plot 1" indicator when first plot is selected
      expect(find.text('Plot 1'), findsOneWidget);
    });

    testWidgets('should NOT show signal panel by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlotGridManager(settingsManager: settingsManager),
          ),
        ),
      );

      await tester.pump();

      // Should NOT show signal panel by default even when plot is selected
      expect(find.text('Available Signals'), findsNothing);
    });

    testWidgets('should handle plot count changes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlotGridManager(settingsManager: settingsManager),
          ),
        ),
      );

      // Change to 3 plots
      final plotCountDropdown = find.byType(DropdownButton<int>);
      await tester.tap(plotCountDropdown);
      await tester.pumpAndSettle();

      await tester.tap(find.text('3').last);
      await tester.pumpAndSettle();

      // Should now show 3 plots in grid
      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.childrenDelegate as SliverChildBuilderDelegate;
      expect(delegate.childCount, 3);
    });
  });

  group('PlotGridManager API Tests', () {
    late SettingsManager settingsManager;
    
    setUp(() {
      TimeSeriesDataManager.resetInstanceForTesting();
      settingsManager = SettingsManager();
    });

    tearDown(() {
      TimeSeriesDataManager.resetInstanceForTesting();
    });

    testWidgets('should support adding signals to selected plot', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlotGridManager(settingsManager: settingsManager),
          ),
        ),
      );

      await tester.pump();

      final gridState = tester.state<PlotGridManagerState>(find.byType(PlotGridManager));

      // Test legacy method for backward compatibility
      expect(() => gridState.assignFieldToSelectedPlot('ATTITUDE', 'roll'), 
             returnsNormally);
      
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('should support multi-signal operations', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlotGridManager(settingsManager: settingsManager),
          ),
        ),
      );

      await tester.pump();

      final gridState = tester.state<PlotGridManagerState>(find.byType(PlotGridManager));

      // Create test signals
      final signal1 = PlotSignalConfiguration(
        id: 'test1',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
      );

      final signal2 = PlotSignalConfiguration(
        id: 'test2',
        messageType: 'ATTITUDE',
        fieldName: 'pitch',
        color: Colors.blue,
      );

      // Test adding multiple signals
      expect(() => gridState.addSignalToSelectedPlot(signal1), returnsNormally);
      expect(() => gridState.addSignalToSelectedPlot(signal2), returnsNormally);
      
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('should provide state access methods', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlotGridManager(settingsManager: settingsManager),
          ),
        ),
      );

      await tester.pump();

      final gridState = tester.state<PlotGridManagerState>(find.byType(PlotGridManager));

      // Test state access methods
      expect(gridState.hasSelectedPlot, isTrue);
      expect(gridState.selectedPlotInfo, contains('Plot'));
      expect(gridState.allPlottedFields, isA<Set<String>>());
      expect(gridState.selectedPlotFields, isA<Map<String, Color>>());
    });

    testWidgets('should support clearing all plots', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlotGridManager(settingsManager: settingsManager),
          ),
        ),
      );

      await tester.pump();

      final gridState = tester.state<PlotGridManagerState>(find.byType(PlotGridManager));

      // Add a signal first
      final signal = PlotSignalConfiguration(
        id: 'test_signal',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
      );
      
      gridState.addSignalToSelectedPlot(signal);
      await tester.pump();

      // Then clear all plots
      expect(() => gridState.clearAllPlots(), returnsNormally);
      
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}