import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_mavlink/dialects/common.dart';
import 'package:js_dash/interfaces/i_byte_source.dart';
import 'package:js_dash/services/mavlink_service.dart';
import 'package:js_dash/services/mavlink_message_tracker.dart';

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
    late MavlinkMessageTracker tracker;
    late MockByteSource mockByteSource;

    setUp(() {
      tracker = MavlinkMessageTracker();
      mockByteSource = MockByteSource();
      service = MavlinkService(byteSource: mockByteSource, tracker: tracker);
    });

    tearDown(() {
      service.dispose();
    });

    test('should initialize successfully', () async {
      await expectLater(service.initialize(), completes);
    });

    test('should have correct initial state', () {
      expect(service.isConnected, isFalse);
    });

    test('should provide stream access', () {
      expect(service.frameStream, isA<Stream>());
      expect(service.heartbeatStream, isA<Stream<Heartbeat>>());
      expect(service.sysStatusStream, isA<Stream<SysStatus>>());
      expect(service.attitudeStream, isA<Stream<Attitude>>());
      expect(service.globalPositionStream, isA<Stream<GlobalPositionInt>>());
      expect(service.vfrHudStream, isA<Stream<VfrHud>>());
    });

    test('should handle initialization without error', () async {
      await service.initialize();
      expect(service.frameStream, isNotNull);
      expect(service.heartbeatStream, isNotNull);
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
