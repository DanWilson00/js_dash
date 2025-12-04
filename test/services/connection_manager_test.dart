import 'package:flutter_test/flutter_test.dart';
import 'package:js_dash/core/connection_config.dart';
import 'package:js_dash/core/connection_status.dart';
import 'package:js_dash/services/connection_manager.dart';

void main() {
  group('ConnectionManager', () {
    late ConnectionManager connectionManager;

    setUp(() {
      // Use injected constructor with null tracker for testing
      connectionManager = ConnectionManager.injected(null);
    });

    tearDown(() {
      connectionManager.dispose();
    });

    test('should start in disconnected state', () {
      expect(
        connectionManager.currentStatus.state,
        ConnectionState.disconnected,
      );
      expect(connectionManager.isConnected, false);
      expect(connectionManager.isConnecting, false);
    });

    test('should create serial connection config', () {
      final config = ConnectionManager.createSerialConfig(
        port: '/dev/ttyUSB0',
        baudRate: 115200,
      );
      expect(config, isA<SerialConnectionConfig>());
      final serialConfig = config as SerialConnectionConfig;
      expect(serialConfig.port, '/dev/ttyUSB0');
      expect(serialConfig.baudRate, 115200);
    });

    test('should create spoof connection config', () {
      final config = ConnectionManager.createSpoofConfig(
        systemId: 2,
        componentId: 3,
        baudRate: 57600,
      );
      expect(config, isA<SpoofConnectionConfig>());
      final spoofConfig = config as SpoofConnectionConfig;
      expect(spoofConfig.systemId, 2);
      expect(spoofConfig.componentId, 3);
      expect(spoofConfig.baudRate, 57600);
    });

    test('should emit status changes', () async {
      final statusUpdates = <ConnectionStatus>[];
      connectionManager.statusStream.listen(statusUpdates.add);

      final spoofConfig = ConnectionManager.createSpoofConfig();

      // Attempt connection (may fail due to lack of real spoof service setup, but should emit status)
      await connectionManager.connect(spoofConfig);

      // Give some time for async operations
      await Future.delayed(const Duration(milliseconds: 10));

      // Should have received at least one status update
      expect(statusUpdates.isNotEmpty, true);
    });

    test('should handle pause and resume', () {
      // Initially not paused
      expect(connectionManager.currentStatus.isPaused, false);

      // Set up a mock connection
      connectionManager.pause();
      // Note: Without a real connection, state won't change to paused
      // This test mainly ensures no exceptions are thrown

      connectionManager.resume();
      // Similarly, this should not throw
    });

    test('should check recent data correctly', () {
      // No data received yet
      expect(connectionManager.hasRecentData(), false);
      expect(
        connectionManager.hasRecentData(const Duration(seconds: 1)),
        false,
      );
    });

    test('should handle dispose correctly', () {
      connectionManager.dispose();
      // Should not throw and clean up resources
    });
  });
}
