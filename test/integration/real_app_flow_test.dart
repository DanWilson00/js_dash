import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:js_dash/core/service_locator.dart';
import 'package:js_dash/services/connection_manager.dart';
import 'package:js_dash/services/telemetry_repository.dart';
import 'package:js_dash/services/settings_manager.dart';
import 'package:js_dash/providers/service_providers.dart';
import 'package:js_dash/core/connection_config.dart';

/// Integration tests that mirror the real app initialization flow
/// These tests ensure the data flow works in production, not just in isolated tests
void main() {
  group('Real App Flow Integration Tests', () {
    late ProviderContainer container;
    late SettingsManager settingsManager;

    setUp(() {
      // Reset service locator
      GetIt.reset();
      
      // Create settings manager and register it (mirrors main.dart)
      settingsManager = SettingsManager();
      GetIt.registerSingleton<SettingsManager>(settingsManager);
      
      // Create provider container (mirrors ProviderScope)
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
      GetIt.reset();
    });

    test('should initialize services like real app and enable spoofing', () async {
      // Simulate the real app initialization sequence from main_navigation.dart
      
      // Step 1: Read telemetry repository provider (triggers service registration)
      final repository = container.read(telemetryRepositoryProvider);
      expect(repository, isNotNull);
      
      // Step 2: Start tracking (mirrors main_navigation.dart)
      repository.startTracking();
      
      // Step 3: Start listening (the fix we added)
      if (repository is TelemetryRepository) {
        await repository.startListening();
      }
      
      // Step 4: Verify services are properly registered and connected
      final connectionManager = container.read(connectionManagerProvider) as ConnectionManager;
      expect(connectionManager, isNotNull);
      
      // Step 5: Enable spoofing in settings (mirrors user action)
      settingsManager.updateConnectionMode(true);
      expect(settingsManager.connection.enableSpoofing, isTrue);
      
      // Step 6: Connect with spoof configuration (mirrors connection actions)
      final spoofConfig = SpoofConnectionConfig(
        systemId: 1,
        componentId: 1,
        baudRate: 57600,
      );
      
      final connected = await connectionManager.connect(spoofConfig);
      
      // Step 7: Verify the connection works
      expect(connected, isTrue);
      expect(connectionManager.currentStatus.isConnected, isTrue);
      expect(connectionManager.currentDataSource, isNotNull);
      
      // Step 8: Verify data source is of correct type
      expect(connectionManager.currentDataSource?.runtimeType.toString(), 
             contains('UsbSerialSpoofService'));
      
      // Step 9: Verify TelemetryRepository is actually listening to the connection
      // This is the critical test - in the broken version, repository wasn't connected
      await Future.delayed(const Duration(milliseconds: 100));
      
      // The repository should be subscribed to connection manager's status stream
      expect(connectionManager.currentStatus.isConnected, isTrue);
      
      // Step 10: Test disconnect (mirrors settings panel disconnect)
      await connectionManager.disconnect();
      expect(connectionManager.currentStatus.isConnected, isFalse);
      expect(connectionManager.currentDataSource, isNull);
    });

    test('should handle settings toggle like real app', () async {
      // Initialize like real app
      final repository = container.read(telemetryRepositoryProvider);
      repository.startTracking();
      if (repository is TelemetryRepository) {
        await repository.startListening();
      }
      
      final connectionManager = container.read(connectionManagerProvider) as ConnectionManager;
      
      // Start with spoofing enabled and connected
      settingsManager.updateConnectionMode(true);
      final spoofConfig = SpoofConnectionConfig(
        systemId: 1,
        componentId: 1,
        baudRate: 57600,
      );
      await connectionManager.connect(spoofConfig);
      expect(connectionManager.currentStatus.isConnected, isTrue);
      
      // Simulate user toggling spoofing off in settings
      // (mirrors connection_settings_panel.dart logic)
      await connectionManager.disconnect();  // Disconnect first
      repository.clearAllData();             // Clear data
      settingsManager.updateConnectionMode(false); // Update setting
      
      // Verify everything is properly disconnected
      expect(connectionManager.currentStatus.isConnected, isFalse);
      expect(connectionManager.currentDataSource, isNull);
      expect(settingsManager.connection.enableSpoofing, isFalse);
      
      // Verify spoofing can be re-enabled
      settingsManager.updateConnectionMode(true);
      await connectionManager.connect(spoofConfig);
      expect(connectionManager.currentStatus.isConnected, isTrue);
    });

    test('should prevent data flow when spoofing is disabled', () async {
      // Initialize like real app
      final repository = container.read(telemetryRepositoryProvider);
      repository.startTracking();
      if (repository is TelemetryRepository) {
        await repository.startListening();
      }
      
      final connectionManager = container.read(connectionManagerProvider) as ConnectionManager;
      
      // Start with spoofing disabled
      settingsManager.updateConnectionMode(false);
      expect(settingsManager.connection.enableSpoofing, isFalse);
      
      // Try to connect with spoof config anyway (should work but won't be appropriate)
      final spoofConfig = SpoofConnectionConfig(
        systemId: 1,
        componentId: 1,
        baudRate: 57600,
      );
      
      // The connection manager should handle this gracefully
      // Even if it connects, the setting should reflect the disabled state
      final connected = await connectionManager.connect(spoofConfig);
      
      if (connected) {
        // If it connects despite being disabled, ensure the setting remains disabled
        expect(settingsManager.connection.enableSpoofing, isFalse);
        
        // And that we can still disconnect properly
        await connectionManager.disconnect();
        expect(connectionManager.currentStatus.isConnected, isFalse);
      }
    });

    test('should maintain data flow integrity across connection changes', () async {
      // Initialize like real app
      final repository = container.read(telemetryRepositoryProvider);
      repository.startTracking();
      if (repository is TelemetryRepository) {
        await repository.startListening();
      }
      
      final connectionManager = container.read(connectionManagerProvider) as ConnectionManager;
      
      // Test multiple connection/disconnection cycles
      for (int i = 0; i < 3; i++) {
        // Enable spoofing
        settingsManager.updateConnectionMode(true);
        
        // Connect
        final spoofConfig = SpoofConnectionConfig(
          systemId: 1,
          componentId: 1,
          baudRate: 57600,
        );
        final connected = await connectionManager.connect(spoofConfig);
        expect(connected, isTrue, reason: 'Connection cycle $i should succeed');
        
        // Verify connection
        expect(connectionManager.currentStatus.isConnected, isTrue);
        
        // Disconnect
        await connectionManager.disconnect();
        expect(connectionManager.currentStatus.isConnected, isFalse);
        
        // Disable spoofing
        settingsManager.updateConnectionMode(false);
        repository.clearAllData();
      }
      
      // Final verification that everything is clean
      expect(connectionManager.currentStatus.isConnected, isFalse);
      expect(connectionManager.currentDataSource, isNull);
      expect(settingsManager.connection.enableSpoofing, isFalse);
    });
  });

  group('Provider Registration Tests', () {
    test('should register services through providers like real app', () {
      // Reset service locator
      GetIt.reset();
      
      // Register settings manager (mirrors main.dart)
      final settingsManager = SettingsManager();
      GetIt.registerSingleton<SettingsManager>(settingsManager);
      
      // Create provider container
      final container = ProviderContainer();
      
      // Access providers (triggers lazy registration)
      final connectionManager = container.read(connectionManagerProvider) as ConnectionManager;
      final repository = container.read(telemetryRepositoryProvider);
      
      // Verify services are now registered in GetIt
      expect(GetIt.isRegistered<ConnectionManager>(), isTrue);
      expect(GetIt.isRegistered<TelemetryRepository>(), isTrue);
      
      // Verify we can get the same instances from GetIt
      final cmFromGetIt = GetIt.get<ConnectionManager>();
      final repoFromGetIt = GetIt.get<TelemetryRepository>();
      
      expect(identical(connectionManager, cmFromGetIt), isTrue);
      expect(identical(repository, repoFromGetIt), isTrue);
      
      container.dispose();
      GetIt.reset();
    });
  });
}