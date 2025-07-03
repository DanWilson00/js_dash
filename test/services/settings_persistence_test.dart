import 'package:flutter_test/flutter_test.dart';
import 'package:js_dash/services/settings_manager.dart';
import 'package:js_dash/models/plot_configuration.dart';
import 'package:flutter/material.dart';

void main() {
  group('Settings Persistence', () {
    late SettingsManager settingsManager;

    setUp(() {
      settingsManager = SettingsManager();
    });

    testWidgets('should save and load plot configurations', (WidgetTester tester) async {
      // Initialize with defaults
      await settingsManager.initialize();
      
      // Create a test plot configuration
      final testPlot = PlotConfiguration(
        id: 'test_plot',
        yAxis: PlotAxisConfiguration(
          signals: [
            PlotSignalConfiguration(
              id: 'test_signal',
              messageType: 'HEARTBEAT',
              fieldName: 'system_status',
              color: Colors.red,
            ),
          ],
        ),
      );
      
      // Update plot settings
      settingsManager.updatePlots(
        settingsManager.plots.copyWith(
          plotCount: 2,
          layout: 'horizontal',
          timeWindow: '30s',
          configurations: [testPlot],
        ),
      );
      
      // Force immediate save
      await settingsManager.saveImmediately();
      
      // Create new manager and load settings
      final newSettingsManager = SettingsManager();
      await newSettingsManager.initialize();
      
      // Verify settings were persisted
      expect(newSettingsManager.plots.plotCount, equals(2));
      expect(newSettingsManager.plots.layout, equals('horizontal'));
      expect(newSettingsManager.plots.timeWindow, equals('30s'));
      expect(newSettingsManager.plots.configurations.length, equals(1));
      expect(newSettingsManager.plots.configurations.first.id, equals('test_plot'));
    });

    testWidgets('should save and load window settings', (WidgetTester tester) async {
      // Initialize with defaults
      await settingsManager.initialize();
      
      // Update window settings
      settingsManager.updateWindowState(
        size: const Size(1200, 800),
        position: const Offset(100, 50),
        maximized: false,
      );
      
      // Force immediate save
      await settingsManager.saveImmediately();
      
      // Create new manager and load settings
      final newSettingsManager = SettingsManager();
      await newSettingsManager.initialize();
      
      // Verify window settings were persisted
      expect(newSettingsManager.window.width, equals(1200));
      expect(newSettingsManager.window.height, equals(800));
      expect(newSettingsManager.window.x, equals(100));
      expect(newSettingsManager.window.y, equals(50));
      expect(newSettingsManager.window.maximized, equals(false));
    });

    testWidgets('should save and load connection settings', (WidgetTester tester) async {
      // Initialize with defaults
      await settingsManager.initialize();
      
      // Update connection settings
      settingsManager.updateConnectionMode(true); // spoof mode
      settingsManager.updatePauseState(true); // paused
      
      // Force immediate save
      await settingsManager.saveImmediately();
      
      // Create new manager and load settings
      final newSettingsManager = SettingsManager();
      await newSettingsManager.initialize();
      
      // Verify connection settings were persisted
      expect(newSettingsManager.connection.useSpoofMode, equals(true));
      expect(newSettingsManager.connection.isPaused, equals(true));
    });
  });
}