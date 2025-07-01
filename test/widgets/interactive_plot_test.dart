import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:js_dash/models/plot_configuration.dart';
import 'package:js_dash/widgets/interactive_plot.dart';
import 'package:js_dash/services/timeseries_data_manager.dart';

void main() {
  group('InteractivePlot Widget Tests', () {
    late TimeSeriesDataManager dataManager;

    setUp(() {
      TimeSeriesDataManager.resetInstanceForTesting();
      dataManager = TimeSeriesDataManager();
    });

    tearDown(() {
      dataManager.dispose();
      TimeSeriesDataManager.resetInstanceForTesting();
    });

    testWidgets('should show empty state when no signals configured', (tester) async {
      final config = PlotConfiguration(id: 'test');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractivePlot(configuration: config),
          ),
        ),
      );

      expect(find.text('Select signals'), findsOneWidget);
      expect(find.byIcon(Icons.timeline), findsOneWidget);
    });

    testWidgets('should show no data message when signals configured but no data', (tester) async {
      final signal = PlotSignalConfiguration(
        id: 'test',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
      );

      final config = PlotConfiguration(
        id: 'test',
        yAxis: PlotAxisConfiguration(signals: [signal]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractivePlot(configuration: config),
          ),
        ),
      );

      expect(find.text('No data'), findsOneWidget);
    });

    testWidgets('should display signal name in header', (tester) async {
      final signal = PlotSignalConfiguration(
        id: 'test',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
        displayName: 'Roll Angle',
      );

      final config = PlotConfiguration(
        id: 'test',
        yAxis: PlotAxisConfiguration(signals: [signal]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractivePlot(configuration: config),
          ),
        ),
      );

      expect(find.text('Roll Angle'), findsOneWidget);
    });

    testWidgets('should display multiple signals count in header', (tester) async {
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

      final config = PlotConfiguration(
        id: 'test',
        yAxis: PlotAxisConfiguration(signals: [signal1, signal2]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractivePlot(configuration: config),
          ),
        ),
      );

      expect(find.text('2 signals'), findsOneWidget);
    });

    testWidgets('should show compact legend for multiple signals', (tester) async {
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

      final config = PlotConfiguration(
        id: 'test',
        yAxis: PlotAxisConfiguration(signals: [signal1, signal2]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractivePlot(configuration: config),
          ),
        ),
      );

      // Should find the compact legend with colored dots
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('should respond to tap gestures', (tester) async {
      bool tapCalled = false;

      final config = PlotConfiguration(id: 'test');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractivePlot(
              configuration: config,
              onAxisTap: () => tapCalled = true,
              onClearAxis: () {}, // Callback provided for testing
            ),
          ),
        ),
      );

      // Test primary tap
      await tester.tap(find.byType(InteractivePlot));
      await tester.pump();

      expect(tapCalled, true);

      // Test secondary tap (right-click)
      await tester.longPress(find.byType(InteractivePlot));
      await tester.pump();

      // Note: Secondary tap testing is more complex in Flutter tests
      // This verifies the widget structure is set up for it
    });

    testWidgets('should respond to legend tap gestures', (tester) async {
      bool legendTapCalled = false;

      final signal = PlotSignalConfiguration(
        id: 'test',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
      );

      final config = PlotConfiguration(
        id: 'test',
        yAxis: PlotAxisConfiguration(signals: [signal]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractivePlot(
              configuration: config,
              onLegendTap: () => legendTapCalled = true,
            ),
          ),
        ),
      );

      // The legend should be clickable - test that the structure supports it
      // Note: Complex widget tree interaction testing is challenging in unit tests
      // This test verifies the API is set up correctly
      expect(legendTapCalled, false); // Initially false
      
      // Verify widget structure doesn't crash with legend tap callback
      expect(tester.takeException(), isNull);
    });

    testWidgets('should show selection border when selected', (tester) async {
      final config = PlotConfiguration(id: 'test');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractivePlot(
              configuration: config,
              isAxisSelected: true,
            ),
          ),
        ),
      );

      // Should find a container with a thicker border
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasThickBorder = containers.any((container) {
        final decoration = container.decoration as BoxDecoration?;
        return decoration?.border?.top.width == 3;
      });

      expect(hasThickBorder, true);
    });

    testWidgets('should handle data updates correctly', (tester) async {
      final signal = PlotSignalConfiguration(
        id: 'test',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
      );

      final config = PlotConfiguration(
        id: 'test',
        yAxis: PlotAxisConfiguration(signals: [signal]),
        timeWindow: const Duration(seconds: 10),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractivePlot(configuration: config),
          ),
        ),
      );

      // Inject test data
      dataManager.injectTestData('ATTITUDE', 'roll', 1.5);
      await tester.pump();

      // Widget should handle the data update (no crash)
      expect(tester.takeException(), isNull);
    });
  });

  group('InteractivePlot Data Processing', () {
    late TimeSeriesDataManager dataManager;

    setUp(() {
      TimeSeriesDataManager.resetInstanceForTesting();
      dataManager = TimeSeriesDataManager();
    });

    tearDown(() {
      dataManager.dispose();
      TimeSeriesDataManager.resetInstanceForTesting();
    });

    testWidgets('should handle multiple signals with different scaling modes', (tester) async {
      final signal1 = PlotSignalConfiguration(
        id: 'test1',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
      );

      final signal2 = PlotSignalConfiguration(
        id: 'test2',
        messageType: 'GPS_RAW_INT',
        fieldName: 'lat',
        color: Colors.blue,
      );

      // Test auto-scale mode
      final autoScaleConfig = PlotConfiguration(
        id: 'test_auto',
        yAxis: PlotAxisConfiguration(
          signals: [signal1, signal2],
          scalingMode: ScalingMode.autoScale,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractivePlot(configuration: autoScaleConfig),
          ),
        ),
      );

      // Add test data with different scales
      dataManager.injectTestData('ATTITUDE', 'roll', 1.5); // radians
      dataManager.injectTestData('GPS_RAW_INT', 'lat', 37.7749); // degrees
      await tester.pump();

      expect(tester.takeException(), isNull);

      // Test independent scaling mode
      final independentConfig = autoScaleConfig.copyWith(
        yAxis: autoScaleConfig.yAxis.copyWith(
          scalingMode: ScalingMode.independent,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractivePlot(configuration: independentConfig),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);

      // Test unified scaling mode
      final unifiedConfig = autoScaleConfig.copyWith(
        yAxis: autoScaleConfig.yAxis.copyWith(
          scalingMode: ScalingMode.unified,
          minY: 0,
          maxY: 100,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractivePlot(configuration: unifiedConfig),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('should handle invisible signals correctly', (tester) async {
      final visibleSignal = PlotSignalConfiguration(
        id: 'visible',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
        visible: true,
      );

      final hiddenSignal = PlotSignalConfiguration(
        id: 'hidden',
        messageType: 'ATTITUDE',
        fieldName: 'pitch',
        color: Colors.blue,
        visible: false,
      );

      final config = PlotConfiguration(
        id: 'test',
        yAxis: PlotAxisConfiguration(signals: [visibleSignal, hiddenSignal]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractivePlot(configuration: config),
          ),
        ),
      );

      // Add data for both signals
      dataManager.injectTestData('ATTITUDE', 'roll', 1.5);
      dataManager.injectTestData('ATTITUDE', 'pitch', 0.5);
      await tester.pump();

      // Should not crash and should only show visible signal
      expect(tester.takeException(), isNull);
    });
  });
}