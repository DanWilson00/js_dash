import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:js_dash/core/connection_config.dart';
import 'package:js_dash/core/connection_status.dart';
import 'package:js_dash/providers/service_providers.dart';
import 'package:js_dash/services/connection_manager.dart';
import 'package:js_dash/services/mavlink_message_tracker.dart';
import 'package:js_dash/services/usb_serial_spoof_service.dart';

void main() {
  late ProviderContainer container;
  late MavlinkMessageTracker tracker;

  setUp(() {
    tracker = MavlinkMessageTracker();
    container = ProviderContainer(
      overrides: [mavlinkMessageTrackerProvider.overrideWithValue(tracker)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('Spoofing service should be created and connected', () async {
    final connectionManager = container.read(connectionManagerProvider);

    // Create spoof config
    final config = ConnectionManager.createSpoofConfig();

    // Connect
    final result = await connectionManager.connect(config);
    expect(result, isTrue);

    // Verify connection state
    expect(connectionManager.currentStatus.state, ConnectionState.connected);

    // Verify data source type
    final dataSource = connectionManager.currentDataSource;
    expect(dataSource, isA<UsbSerialSpoofService>());
    expect(dataSource!.isConnected, isTrue);
  });

  test('Spoofing service should generate data', () async {
    final connectionManager = container.read(connectionManagerProvider);
    final config = ConnectionManager.createSpoofConfig();
    await connectionManager.connect(config);

    // Wait for some data
    await Future.delayed(const Duration(milliseconds: 200));

    // Check if data was received
    expect(connectionManager.hasRecentData(), isTrue);

    // Check tracker
    expect(tracker.totalMessages > 0, isTrue);
  });

  test('ConnectionManager should properly disconnect spoof service', () async {
    final connectionManager = container.read(connectionManagerProvider);

    final spoofConfig = ConnectionManager.createSpoofConfig();

    await connectionManager.connect(spoofConfig);
    expect(connectionManager.currentStatus.isConnected, isTrue);

    final spoofService =
        connectionManager.currentDataSource as UsbSerialSpoofService;
    expect(spoofService, isNotNull);

    await connectionManager.disconnect();
    expect(connectionManager.currentStatus.isConnected, isFalse);
    expect(connectionManager.currentDataSource, isNull);
  });

  test('Multiple disconnect calls should be safe', () async {
    final connectionManager = container.read(connectionManagerProvider);

    // Should be safe to disconnect when not connected
    await connectionManager.disconnect();
    expect(connectionManager.currentStatus.isConnected, isFalse);

    // Connect then disconnect multiple times
    final spoofConfig = ConnectionManager.createSpoofConfig();

    await connectionManager.connect(spoofConfig);
    await connectionManager.disconnect();
    await connectionManager.disconnect(); // Should be safe

    expect(connectionManager.currentStatus.isConnected, isFalse);
  });
}
