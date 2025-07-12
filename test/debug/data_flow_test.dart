import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:js_dash/core/service_locator.dart';
import 'package:js_dash/services/connection_manager.dart';
import 'package:js_dash/services/telemetry_repository.dart';
import 'package:js_dash/services/settings_manager.dart';
import 'package:js_dash/core/connection_config.dart';
import 'package:js_dash/providers/service_providers.dart';

/// Debug test to trace data flow with logging
/// This test should help us see where the data flow breaks
void main() {
  group('Data Flow Debug Tests', () {
    setUp(() {
      GetIt.reset();
    });

    tearDown(() {
      GetIt.reset();
    });

    test('should trace complete data flow from spoof service to repository', () async {
      print('\n🚀 === STARTING DATA FLOW DEBUG TEST ===');
      
      // Step 1: Set up services like real app
      print('\n📋 Step 1: Setting up services');
      final settingsManager = SettingsManager();
      GetIt.registerSingleton<SettingsManager>(settingsManager);
      
      final container = ProviderContainer();
      
      // Step 2: Enable spoofing in settings
      print('\n📋 Step 2: Enabling spoofing in settings');
      settingsManager.updateConnectionMode(true);
      expect(settingsManager.connection.enableSpoofing, isTrue);
      print('✅ Spoofing enabled in settings');
      
      // Step 3: Get services through providers (like real app)
      print('\n📋 Step 3: Getting services through providers');
      final repository = container.read(telemetryRepositoryProvider) as TelemetryRepository;
      final connectionManager = container.read(connectionManagerProvider) as ConnectionManager;
      
      // Step 4: Initialize repository like real app
      print('\n📋 Step 4: Initializing repository');
      repository.startTracking();
      await repository.startListening();
      
      // Step 5: Create spoof connection and connect
      print('\n📋 Step 5: Creating spoof connection');
      final spoofConfig = SpoofConnectionConfig(
        systemId: 1,
        componentId: 1,
        baudRate: 57600,
      );
      
      print('\n📋 Step 6: Attempting to connect');
      final connected = await connectionManager.connect(spoofConfig);
      expect(connected, isTrue);
      
      print('\n📋 Step 7: Verifying connection');
      expect(connectionManager.currentStatus.isConnected, isTrue);
      print('✅ Connection manager reports connected');
      
      // Step 8: Wait for data and check if it flows
      print('\n📋 Step 8: Waiting for data flow (3 seconds)');
      await Future.delayed(const Duration(seconds: 3));
      
      // Step 9: Check if repository has received any data
      print('\n📋 Step 9: Checking if repository received data');
      final summary = repository.getDataSummary();
      print('📊 Data summary: $summary');
      
      if (summary.isEmpty) {
        print('❌ NO DATA RECEIVED BY REPOSITORY');
      } else {
        print('✅ Repository has data: ${summary.keys.join(", ")}');
      }
      
      // Step 10: Check if data source is producing data
      print('\n📋 Step 10: Checking data source');
      final dataSource = connectionManager.currentDataSource;
      print('🔗 Current data source: ${dataSource?.runtimeType}');
      
      if (dataSource != null) {
        // Listen directly to data source for a moment
        print('👂 Listening directly to data source stream...');
        int messageCount = 0;
        final subscription = dataSource.messageStream.listen((message) {
          messageCount++;
          print('📨 Direct message from data source: ${message.runtimeType} (count: $messageCount)');
        });
        
        await Future.delayed(const Duration(seconds: 2));
        await subscription.cancel();
        
        if (messageCount > 0) {
          print('✅ Data source IS producing messages ($messageCount received)');
        } else {
          print('❌ Data source is NOT producing messages');
        }
      }
      
      print('\n🏁 === DATA FLOW DEBUG TEST COMPLETE ===\n');
      
      container.dispose();
    });
  });
}