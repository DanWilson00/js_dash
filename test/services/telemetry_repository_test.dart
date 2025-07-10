import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:js_dash/interfaces/i_data_source.dart';
import 'package:js_dash/services/telemetry_repository.dart';
import 'package:js_dash/services/connection_manager.dart';
import 'package:js_dash/services/timeseries_data_manager.dart';
import 'package:dart_mavlink/dialects/common.dart';

import 'package:js_dash/core/service_locator.dart';

// Mock data source for testing
class MockDataSource implements IDataSource, Disposable {
  final StreamController<dynamic> _messageController = StreamController<dynamic>.broadcast();
  bool _isConnected = false;
  bool _isPaused = false;

  @override
  Stream<dynamic> get messageStream => _messageController.stream;

  @override
  Stream<Heartbeat> get heartbeatStream => Stream.empty();

  @override
  Stream<SysStatus> get sysStatusStream => Stream.empty();

  @override
  Stream<Attitude> get attitudeStream => Stream.empty();

  @override
  Stream<GlobalPositionInt> get gpsStream => Stream.empty();

  @override
  Stream<VfrHud> get vfrHudStream => Stream.empty();

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isPaused => _isPaused;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> connect() async {
    _isConnected = true;
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
  }

  @override
  void pause() {
    _isPaused = true;
  }

  @override
  void resume() {
    _isPaused = false;
  }

  void addMessage(dynamic message) {
    _messageController.add(message);
  }

  @override
  void dispose() {
    _messageController.close();
  }
}

void main() {
  group('TelemetryRepository', () {
    late TelemetryRepository repository;
    late ConnectionManager connectionManager;
    late TimeSeriesDataManager timeSeriesManager;

    setUp(() {
      connectionManager = ConnectionManager.forTesting();
      TimeSeriesDataManager.resetInstanceForTesting();
      timeSeriesManager = TimeSeriesDataManager();
      repository = TelemetryRepository.forTesting(
        connectionManager: connectionManager,
        timeSeriesManager: timeSeriesManager,
      );
    });

    tearDown(() {
      repository.dispose();
      connectionManager.dispose();
      timeSeriesManager.dispose();
    });

    test('should initialize correctly', () async {
      await repository.initialize();
      // Should not throw and complete successfully
    });

    test('should delegate data stream to TimeSeriesDataManager', () {
      final dataStream = repository.dataStream;
      expect(dataStream, isA<Stream<Map<String, dynamic>>>());
      // The actual stream comes from TimeSeriesDataManager
      expect(dataStream, equals(timeSeriesManager.dataStream));
    });

    test('should delegate field operations to TimeSeriesDataManager', () {
      // Add some test data to the time series manager
      timeSeriesManager.injectTestData('TEST_MESSAGE', 'testField', 42.0);
      
      final fields = repository.getAvailableFields();
      expect(fields, contains('TEST_MESSAGE.testField'));
      
      final fieldData = repository.getFieldData('TEST_MESSAGE', 'testField');
      expect(fieldData.length, 1);
      expect(fieldData.first.value, 42.0);
      
      final messageFields = repository.getFieldsForMessage('TEST_MESSAGE');
      expect(messageFields, contains('testField'));
    });

    test('should handle pause and resume correctly', () {
      expect(repository.isPaused, false);
      
      repository.pause();
      expect(repository.isPaused, true);
      expect(timeSeriesManager.isPaused, true);
      
      repository.resume();
      expect(repository.isPaused, false);
      expect(timeSeriesManager.isPaused, false);
    });

    test('should handle data clearing', () {
      // Add some test data
      timeSeriesManager.injectTestData('TEST_MESSAGE', 'testField', 42.0);
      expect(repository.getAvailableFields().isNotEmpty, true);
      
      repository.clearAllData();
      expect(repository.getAvailableFields().isEmpty, true);
    });

    test('should provide connection convenience methods', () async {
      expect(repository.isConnected, false);
      expect(repository.currentDataSource, isNull);
      
      // These methods delegate to connection manager
      // Since we don't have a real connection setup, they may not succeed
      // but should not throw exceptions
      repository.pauseConnection();
      repository.resumeConnection();
      await repository.disconnect();
    });

    test('should get data summary correctly', () {
      // Add some test data
      timeSeriesManager.injectTestData('TEST_MESSAGE', 'field1', 1.0);
      timeSeriesManager.injectTestData('TEST_MESSAGE', 'field2', 2.0);
      
      final summary = repository.getDataSummary();
      expect(summary, isA<Map<String, int>>());
      expect(summary.keys, contains('TEST_MESSAGE.field1'));
      expect(summary.keys, contains('TEST_MESSAGE.field2'));
    });

    test('should start and stop listening correctly', () async {
      await repository.startListening();
      // Should complete without error
      
      await repository.stopListening();
      // Should complete without error
    });

    test('should handle dispose correctly', () {
      repository.dispose();
      // Should clean up resources without throwing
    });
  });
}