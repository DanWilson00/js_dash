import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:js_dash/models/plot_configuration.dart';

void main() {
  group('PlotSignalConfiguration', () {
    test('should create signal with required fields', () {
      final signal = PlotSignalConfiguration(
        id: 'test_signal',
        messageType: 'HEARTBEAT',
        fieldName: 'type',
        color: Colors.blue,
      );

      expect(signal.id, 'test_signal');
      expect(signal.messageType, 'HEARTBEAT');
      expect(signal.fieldName, 'type');
      expect(signal.color, Colors.blue);
      expect(signal.visible, true);
      expect(signal.lineWidth, 2.0);
      expect(signal.showDots, false);
    });

    test('should generate correct fieldKey', () {
      final signal = PlotSignalConfiguration(
        id: 'test',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
      );

      expect(signal.fieldKey, 'ATTITUDE.roll');
    });

    test('should use displayName when provided', () {
      final signal = PlotSignalConfiguration(
        id: 'test',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
        displayName: 'Roll Angle',
      );

      expect(signal.effectiveDisplayName, 'Roll Angle');
    });

    test('should auto-generate displayName when not provided', () {
      final signal = PlotSignalConfiguration(
        id: 'test',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
      );

      expect(signal.effectiveDisplayName, 'ATTITUDE.roll');
    });

    test('should create copy with updated properties', () {
      final signal = PlotSignalConfiguration(
        id: 'test',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
      );

      final updated = signal.copyWith(
        color: Colors.blue,
        visible: false,
        lineWidth: 3.0,
      );

      expect(updated.id, signal.id);
      expect(updated.messageType, signal.messageType);
      expect(updated.fieldName, signal.fieldName);
      expect(updated.color, Colors.blue);
      expect(updated.visible, false);
      expect(updated.lineWidth, 3.0);
    });

    test('should implement equality by id', () {
      final signal1 = PlotSignalConfiguration(
        id: 'test',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
      );

      final signal2 = PlotSignalConfiguration(
        id: 'test',
        messageType: 'GPS_RAW_INT',
        fieldName: 'lat',
        color: Colors.blue,
      );

      final signal3 = PlotSignalConfiguration(
        id: 'different',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
      );

      expect(signal1, signal2); // Same ID
      expect(signal1, isNot(signal3)); // Different ID
    });
  });

  group('PlotAxisConfiguration', () {
    test('should create empty configuration by default', () {
      final config = PlotAxisConfiguration();

      expect(config.signals, isEmpty);
      expect(config.hasData, false);
      expect(config.hasVisibleSignals, false);
      expect(config.scalingMode, ScalingMode.autoScale);
    });

    test('should report hasData when signals exist', () {
      final signal = PlotSignalConfiguration(
        id: 'test',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
      );

      final config = PlotAxisConfiguration(signals: [signal]);

      expect(config.hasData, true);
      expect(config.hasVisibleSignals, true);
    });

    test('should filter visible signals correctly', () {
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

      final config = PlotAxisConfiguration(
        signals: [visibleSignal, hiddenSignal],
      );

      expect(config.visibleSignals, [visibleSignal]);
      expect(config.hasVisibleSignals, true);
    });

    test('should generate appropriate display names', () {
      final config = PlotAxisConfiguration();
      expect(config.displayName, 'No Data');

      final singleSignal = PlotSignalConfiguration(
        id: 'test',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
        displayName: 'Roll Angle',
      );

      final configWithOne = PlotAxisConfiguration(signals: [singleSignal]);
      expect(configWithOne.displayName, 'Roll Angle');

      final secondSignal = PlotSignalConfiguration(
        id: 'test2',
        messageType: 'ATTITUDE',
        fieldName: 'pitch',
        color: Colors.blue,
      );

      final configWithMultiple = PlotAxisConfiguration(
        signals: [singleSignal, secondSignal],
      );
      expect(configWithMultiple.displayName, '2 signals');
    });

    test('should add signal correctly', () {
      final config = PlotAxisConfiguration();
      final signal = PlotSignalConfiguration(
        id: 'test',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
      );

      final updated = config.addSignal(signal);

      expect(updated.signals, [signal]);
      expect(config.signals, isEmpty); // Original unchanged
    });

    test('should remove signal by id', () {
      final signal1 = PlotSignalConfiguration(
        id: 'signal1',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
      );

      final signal2 = PlotSignalConfiguration(
        id: 'signal2',
        messageType: 'ATTITUDE',
        fieldName: 'pitch',
        color: Colors.blue,
      );

      final config = PlotAxisConfiguration(signals: [signal1, signal2]);
      final updated = config.removeSignal('signal1');

      expect(updated.signals, [signal2]);
    });

    test('should update signal correctly', () {
      final signal = PlotSignalConfiguration(
        id: 'test',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
      );

      final config = PlotAxisConfiguration(signals: [signal]);
      final updatedSignal = signal.copyWith(color: Colors.blue);
      final updatedConfig = config.updateSignal(updatedSignal);

      expect(updatedConfig.signals.first.color, Colors.blue);
    });

    test('should support legacy compatibility', () {
      final config = PlotAxisConfiguration();

      // Test legacy copyWith parameters
      final updated = config.copyWith(
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        units: 'rad',
      );

      expect(updated.signals.length, 1);
      expect(updated.signals.first.messageType, 'ATTITUDE');
      expect(updated.signals.first.fieldName, 'roll');
      expect(updated.signals.first.units, 'rad');
      
      // Test legacy getters
      expect(updated.messageType, 'ATTITUDE');
      expect(updated.fieldName, 'roll');
      expect(updated.units, 'rad');
    });

    test('should clear signals', () {
      final signal = PlotSignalConfiguration(
        id: 'test',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
      );

      final config = PlotAxisConfiguration(
        signals: [signal],
        scalingMode: ScalingMode.unified,
        minY: 10,
        maxY: 20,
      );

      final cleared = config.clear();

      expect(cleared.signals, isEmpty);
      expect(cleared.scalingMode, ScalingMode.unified); // Preserved
      expect(cleared.minY, 10); // Preserved
      expect(cleared.maxY, 20); // Preserved
    });
  });

  group('PlotConfiguration', () {
    test('should create configuration with default axis', () {
      final config = PlotConfiguration(id: 'test');

      expect(config.id, 'test');
      expect(config.title, 'Time Series Plot');
      expect(config.yAxis.signals, isEmpty);
      expect(config.timeWindow, const Duration(minutes: 5));
    });

    test('should support signal management operations', () {
      final config = PlotConfiguration(id: 'test');
      final signal = PlotSignalConfiguration(
        id: 'test_signal',
        messageType: 'ATTITUDE',
        fieldName: 'roll',
        color: Colors.red,
      );

      // Add signal
      final withSignal = config.addSignal(signal);
      expect(withSignal.yAxis.signals, [signal]);

      // Update signal
      final updatedSignal = signal.copyWith(color: Colors.blue);
      final withUpdatedSignal = withSignal.updateSignal(updatedSignal);
      expect(withUpdatedSignal.yAxis.signals.first.color, Colors.blue);

      // Remove signal
      final withoutSignal = withUpdatedSignal.removeSignal('test_signal');
      expect(withoutSignal.yAxis.signals, isEmpty);
    });
  });

  group('SignalColorPalette', () {
    test('should return colors in sequence', () {
      final color0 = SignalColorPalette.getNextColor(0);
      final color1 = SignalColorPalette.getNextColor(1);
      final color2 = SignalColorPalette.getNextColor(2);

      expect(color0, isNot(color1));
      expect(color1, isNot(color2));
      expect(color0, isNot(color2));
    });

    test('should cycle through colors when index exceeds palette size', () {
      final availableColors = SignalColorPalette.availableColors;
      final paletteSize = availableColors.length;

      final firstColor = SignalColorPalette.getNextColor(0);
      final cycledColor = SignalColorPalette.getNextColor(paletteSize);

      expect(firstColor, cycledColor);
    });

    test('should return consistent color for same signal ID', () {
      const signalId = 'ATTITUDE.roll';
      
      final color1 = SignalColorPalette.getColorForSignal(signalId);
      final color2 = SignalColorPalette.getColorForSignal(signalId);

      expect(color1, color2);
    });

    test('should provide access to available colors', () {
      final colors = SignalColorPalette.availableColors;
      
      expect(colors, isNotEmpty);
      expect(colors.length, greaterThan(5)); // Should have reasonable variety
    });
  });

  group('ScalingMode', () {
    test('should have expected values', () {
      expect(ScalingMode.values, [
        ScalingMode.unified,
        ScalingMode.independent,
        ScalingMode.autoScale,
      ]);
    });
  });
}