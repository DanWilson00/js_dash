import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:js_dash/core/connection_status.dart';
import 'package:js_dash/mavlink/mavlink.dart';
import 'package:js_dash/providers/service_providers.dart';
import 'package:js_dash/services/connection_manager.dart';
import 'package:js_dash/services/generic_message_tracker.dart';
import 'package:js_dash/services/mavlink_service.dart';

void main() {
  late ProviderContainer container;
  late MavlinkMetadataRegistry registry;
  late GenericMessageTracker tracker;

  setUp(() {
    registry = MavlinkMetadataRegistry();
    // Load test metadata
    registry.loadFromJsonString('''
{
  "schema_version": "1.0.0",
  "enums": {},
  "messages": {
    "0": {
      "id": 0,
      "name": "HEARTBEAT",
      "description": "Heartbeat",
      "crc_extra": 50,
      "encoded_length": 9,
      "fields": [
        {"name": "custom_mode", "type": "uint32_t", "base_type": "uint32_t", "offset": 0, "size": 4, "array_length": 1, "description": "", "extension": false},
        {"name": "type", "type": "uint8_t", "base_type": "uint8_t", "offset": 4, "size": 1, "array_length": 1, "description": "", "extension": false},
        {"name": "autopilot", "type": "uint8_t", "base_type": "uint8_t", "offset": 5, "size": 1, "array_length": 1, "description": "", "extension": false},
        {"name": "base_mode", "type": "uint8_t", "base_type": "uint8_t", "offset": 6, "size": 1, "array_length": 1, "description": "", "extension": false},
        {"name": "system_status", "type": "uint8_t", "base_type": "uint8_t", "offset": 7, "size": 1, "array_length": 1, "description": "", "extension": false},
        {"name": "mavlink_version", "type": "uint8_t", "base_type": "uint8_t", "offset": 8, "size": 1, "array_length": 1, "description": "", "extension": false}
      ]
    },
    "30": {
      "id": 30,
      "name": "ATTITUDE",
      "description": "Attitude",
      "crc_extra": 39,
      "encoded_length": 28,
      "fields": [
        {"name": "time_boot_ms", "type": "uint32_t", "base_type": "uint32_t", "offset": 0, "size": 4, "array_length": 1, "description": "", "extension": false},
        {"name": "roll", "type": "float", "base_type": "float", "offset": 4, "size": 4, "array_length": 1, "description": "", "extension": false},
        {"name": "pitch", "type": "float", "base_type": "float", "offset": 8, "size": 4, "array_length": 1, "description": "", "extension": false},
        {"name": "yaw", "type": "float", "base_type": "float", "offset": 12, "size": 4, "array_length": 1, "description": "", "extension": false},
        {"name": "rollspeed", "type": "float", "base_type": "float", "offset": 16, "size": 4, "array_length": 1, "description": "", "extension": false},
        {"name": "pitchspeed", "type": "float", "base_type": "float", "offset": 20, "size": 4, "array_length": 1, "description": "", "extension": false},
        {"name": "yawspeed", "type": "float", "base_type": "float", "offset": 24, "size": 4, "array_length": 1, "description": "", "extension": false}
      ]
    },
    "33": {
      "id": 33,
      "name": "GLOBAL_POSITION_INT",
      "description": "Global position",
      "crc_extra": 104,
      "encoded_length": 28,
      "fields": [
        {"name": "time_boot_ms", "type": "uint32_t", "base_type": "uint32_t", "offset": 0, "size": 4, "array_length": 1, "description": "", "extension": false},
        {"name": "lat", "type": "int32_t", "base_type": "int32_t", "offset": 4, "size": 4, "array_length": 1, "description": "", "extension": false},
        {"name": "lon", "type": "int32_t", "base_type": "int32_t", "offset": 8, "size": 4, "array_length": 1, "description": "", "extension": false},
        {"name": "alt", "type": "int32_t", "base_type": "int32_t", "offset": 12, "size": 4, "array_length": 1, "description": "", "extension": false},
        {"name": "relative_alt", "type": "int32_t", "base_type": "int32_t", "offset": 16, "size": 4, "array_length": 1, "description": "", "extension": false},
        {"name": "vx", "type": "int16_t", "base_type": "int16_t", "offset": 20, "size": 2, "array_length": 1, "description": "", "extension": false},
        {"name": "vy", "type": "int16_t", "base_type": "int16_t", "offset": 22, "size": 2, "array_length": 1, "description": "", "extension": false},
        {"name": "vz", "type": "int16_t", "base_type": "int16_t", "offset": 24, "size": 2, "array_length": 1, "description": "", "extension": false},
        {"name": "hdg", "type": "uint16_t", "base_type": "uint16_t", "offset": 26, "size": 2, "array_length": 1, "description": "", "extension": false}
      ]
    },
    "74": {
      "id": 74,
      "name": "VFR_HUD",
      "description": "VFR HUD",
      "crc_extra": 20,
      "encoded_length": 20,
      "fields": [
        {"name": "airspeed", "type": "float", "base_type": "float", "offset": 0, "size": 4, "array_length": 1, "description": "", "extension": false},
        {"name": "groundspeed", "type": "float", "base_type": "float", "offset": 4, "size": 4, "array_length": 1, "description": "", "extension": false},
        {"name": "alt", "type": "float", "base_type": "float", "offset": 8, "size": 4, "array_length": 1, "description": "", "extension": false},
        {"name": "climb", "type": "float", "base_type": "float", "offset": 12, "size": 4, "array_length": 1, "description": "", "extension": false},
        {"name": "heading", "type": "int16_t", "base_type": "int16_t", "offset": 16, "size": 2, "array_length": 1, "description": "", "extension": false},
        {"name": "throttle", "type": "uint16_t", "base_type": "uint16_t", "offset": 18, "size": 2, "array_length": 1, "description": "", "extension": false}
      ]
    },
    "1": {
      "id": 1,
      "name": "SYS_STATUS",
      "description": "System status",
      "crc_extra": 124,
      "encoded_length": 31,
      "fields": [
        {"name": "onboard_control_sensors_present", "type": "uint32_t", "base_type": "uint32_t", "offset": 0, "size": 4, "array_length": 1, "description": "", "extension": false},
        {"name": "onboard_control_sensors_enabled", "type": "uint32_t", "base_type": "uint32_t", "offset": 4, "size": 4, "array_length": 1, "description": "", "extension": false},
        {"name": "onboard_control_sensors_health", "type": "uint32_t", "base_type": "uint32_t", "offset": 8, "size": 4, "array_length": 1, "description": "", "extension": false},
        {"name": "load", "type": "uint16_t", "base_type": "uint16_t", "offset": 12, "size": 2, "array_length": 1, "description": "", "extension": false},
        {"name": "voltage_battery", "type": "uint16_t", "base_type": "uint16_t", "offset": 14, "size": 2, "array_length": 1, "description": "", "extension": false},
        {"name": "current_battery", "type": "int16_t", "base_type": "int16_t", "offset": 16, "size": 2, "array_length": 1, "description": "", "extension": false},
        {"name": "drop_rate_comm", "type": "uint16_t", "base_type": "uint16_t", "offset": 18, "size": 2, "array_length": 1, "description": "", "extension": false},
        {"name": "errors_comm", "type": "uint16_t", "base_type": "uint16_t", "offset": 20, "size": 2, "array_length": 1, "description": "", "extension": false},
        {"name": "errors_count1", "type": "uint16_t", "base_type": "uint16_t", "offset": 22, "size": 2, "array_length": 1, "description": "", "extension": false},
        {"name": "errors_count2", "type": "uint16_t", "base_type": "uint16_t", "offset": 24, "size": 2, "array_length": 1, "description": "", "extension": false},
        {"name": "errors_count3", "type": "uint16_t", "base_type": "uint16_t", "offset": 26, "size": 2, "array_length": 1, "description": "", "extension": false},
        {"name": "errors_count4", "type": "uint16_t", "base_type": "uint16_t", "offset": 28, "size": 2, "array_length": 1, "description": "", "extension": false},
        {"name": "battery_remaining", "type": "int8_t", "base_type": "int8_t", "offset": 30, "size": 1, "array_length": 1, "description": "", "extension": false}
      ]
    }
  }
}
''');
    tracker = GenericMessageTracker(registry);
    tracker.startTracking();
    container = ProviderContainer(
      overrides: [
        mavlinkRegistryProvider.overrideWith((ref) => registry),
        messageTrackerProvider.overrideWith((ref) => tracker),
      ],
    );
  });

  tearDown(() {
    tracker.stopTracking();
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

    // Verify data source type - now using MavlinkService with SpoofByteSource
    final dataSource = connectionManager.currentDataSource;
    expect(dataSource, isA<MavlinkService>());
    expect(dataSource!.isConnected, isTrue);
  });

  test('Spoofing service should generate data', () async {
    final connectionManager = container.read(connectionManagerProvider);
    final config = ConnectionManager.createSpoofConfig();
    await connectionManager.connect(config);

    // Wait for some data
    await Future.delayed(const Duration(seconds: 2));

    // Check tracker - main verification
    expect(
      tracker.totalMessages > 0,
      isTrue,
      reason: 'Expected messages to be tracked, got ${tracker.totalMessages}',
    );
  });

  test('ConnectionManager should properly disconnect spoof service', () async {
    final connectionManager = container.read(connectionManagerProvider);

    final spoofConfig = ConnectionManager.createSpoofConfig();

    await connectionManager.connect(spoofConfig);
    expect(connectionManager.currentStatus.isConnected, isTrue);

    final service = connectionManager.currentDataSource as MavlinkService;
    expect(service, isNotNull);

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
