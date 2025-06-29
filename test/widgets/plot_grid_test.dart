import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:js_dash/widgets/plot_grid.dart';
import 'package:js_dash/services/timeseries_data_manager.dart';

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
  });
}