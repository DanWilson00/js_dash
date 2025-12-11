import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:js_dash/interfaces/i_byte_source.dart';
import 'package:js_dash/mavlink/mavlink.dart';
import 'package:js_dash/services/generic_message_tracker.dart';
import 'package:js_dash/services/mavlink_service.dart';

/// Mock byte source for testing
class MockByteSource implements IByteSource {
  final StreamController<Uint8List> _controller = StreamController<Uint8List>.broadcast();
  bool _isConnected = false;

  @override
  Stream<Uint8List> get bytes => _controller.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> connect() async {
    _isConnected = true;
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
  }

  @override
  void dispose() {
    _controller.close();
  }

  void emitBytes(Uint8List data) {
    if (!_controller.isClosed) {
      _controller.add(data);
    }
  }
}

void main() {
  group('MavlinkService', () {
    late MavlinkService service;
    late MavlinkMetadataRegistry registry;
    late GenericMessageTracker tracker;
    late MockByteSource mockByteSource;

    setUp(() {
      registry = MavlinkMetadataRegistry();
      // Load minimal test metadata
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
    }
  }
}
''');
      tracker = GenericMessageTracker(registry);
      tracker.startTracking();
      mockByteSource = MockByteSource();
      service = MavlinkService(
        byteSource: mockByteSource,
        registry: registry,
        tracker: tracker,
      );
    });

    tearDown(() {
      tracker.stopTracking();
      service.dispose();
    });

    test('should initialize successfully', () async {
      await expectLater(service.initialize(), completes);
    });

    test('should have correct initial state', () {
      expect(service.isConnected, isFalse);
    });

    test('should provide stream access', () {
      expect(service.messageStream, isA<Stream<MavlinkMessage>>());
    });

    test('should provide filtered streams', () {
      expect(service.streamByName('HEARTBEAT'), isA<Stream<MavlinkMessage>>());
      expect(service.streamByName('ATTITUDE'), isA<Stream<MavlinkMessage>>());
      expect(service.streamById(0), isA<Stream<MavlinkMessage>>());
      expect(service.streamById(30), isA<Stream<MavlinkMessage>>());
    });

    test('should handle initialization without error', () async {
      await service.initialize();
      expect(service.messageStream, isNotNull);
    });

    test('should connect using byte source', () async {
      await service.connect();
      expect(mockByteSource.isConnected, isTrue);
      expect(service.isConnected, isTrue);
    });

    test('should disconnect when connected', () async {
      await service.connect();
      await service.disconnect();
      expect(mockByteSource.isConnected, isFalse);
      expect(service.isConnected, isFalse);
    });

    test('should handle disconnect when not connected', () async {
      await expectLater(service.disconnect(), completes);
      expect(service.isConnected, isFalse);
    });

    test('should handle dispose without error', () {
      expect(() => service.dispose(), returnsNormally);
    });
  });
}
