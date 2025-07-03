import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:js_dash/views/telemetry/plot_grid.dart';
import 'package:js_dash/services/timeseries_data_manager.dart';
import 'package:js_dash/models/plot_configuration.dart';

void main() {
  group('PlotGridManager Basic Tests', () {
    setUp(() {
      TimeSeriesDataManager.resetInstanceForTesting();
    });

    tearDown(() {
      TimeSeriesDataManager.resetInstanceForTesting();
    });

    testWidgets('should build and display basic structure', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlotGridManager(),
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
        const MaterialApp(
          home: Scaffold(
            body: PlotGridManager(),
          ),
        ),
      );

      await tester.pump();

      // Should have at least one plot widget
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('should show plot count dropdown options', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlotGridManager(),
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
        const MaterialApp(
          home: Scaffold(
            body: PlotGridManager(),
          ),
        ),
      );

      await tester.pump();

      // Should show "Plot 1" indicator when first plot is selected
      expect(find.text('Plot 1'), findsOneWidget);
    });

    testWidgets('should NOT show signal panel by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlotGridManager(),
          ),
        ),
      );

      await tester.pump();

      // Should NOT show signal panel by default even when plot is selected
      expect(find.text('Available Signals'), findsNothing);
    });

    testWidgets('should handle plot count changes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlotGridManager(),
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

  group('PlotGridManager Multi-Signal Tests', () {
    setUp(() {
      TimeSeriesDataManager.resetInstanceForTesting();
    });

    tearDown(() {
      TimeSeriesDataManager.resetInstanceForTesting();
    });

    testWidgets('should support adding signals to selected plot', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlotGridManager(),
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
        const MaterialApp(
          home: Scaffold(
            body: PlotGridManager(),
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

    testWidgets('should handle time window updates', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlotGridManager(),
          ),
        ),
      );

      // Change time window
      final timeDropdown = find.byType(DropdownButton<TimeWindowOption>);
      await tester.tap(timeDropdown);
      await tester.pumpAndSettle();

      await tester.tap(find.text('30s').last);
      await tester.pumpAndSettle();

      // Should update without issues
      expect(tester.takeException(), isNull);
    });

    testWidgets('should handle plot reduction correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlotGridManager(),
          ),
        ),
      );

      // Increase to 3 plots
      final plotCountDropdown = find.byType(DropdownButton<int>);
      await tester.tap(plotCountDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('3').last);
      await tester.pumpAndSettle();

      // Then reduce back to 1
      await tester.tap(plotCountDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('1').last);
      await tester.pumpAndSettle();

      // Should handle the reduction correctly
      expect(tester.takeException(), isNull);
      expect(find.text('Plot 1'), findsOneWidget);
    });

    testWidgets('should provide public API for integration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlotGridManager(),
          ),
        ),
      );

      final gridState = tester.state<PlotGridManagerState>(find.byType(PlotGridManager));

      // Test public API methods
      expect(gridState.hasSelectedPlot, true);
      expect(gridState.selectedPlotInfo, 'Plot 1');

      // Test that signal assignment API works
      expect(() => gridState.assignFieldToSelectedPlot('GPS_RAW_INT', 'lat'), 
             returnsNormally);
      
      await tester.pump();
    });

    testWidgets('should maintain signal panel state correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlotGridManager(),
          ),
        ),
      );

      final gridState = tester.state<PlotGridManagerState>(find.byType(PlotGridManager));

      // Add a signal to make legend clickable
      gridState.assignFieldToSelectedPlot('ATTITUDE', 'roll');
      await tester.pump();

      // Panel should not be visible initially
      expect(find.text('Available Signals'), findsNothing);

      // Test that the widget can handle signal management without crashes
      expect(tester.takeException(), isNull);
    });

    testWidgets('should handle signal addition and removal', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlotGridManager(),
          ),
        ),
      );

      final gridState = tester.state<PlotGridManagerState>(find.byType(PlotGridManager));

      // Test adding signals via the public API
      gridState.assignFieldToSelectedPlot('ATTITUDE', 'roll');
      await tester.pump();
      expect(tester.takeException(), isNull);

      gridState.assignFieldToSelectedPlot('ATTITUDE', 'pitch');
      await tester.pump();
      expect(tester.takeException(), isNull);

      // The plot should now have signals
      expect(gridState.hasSelectedPlot, true);
    });
  });
}