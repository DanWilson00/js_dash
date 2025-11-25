import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_mavlink/dialects/common.dart';
import 'package:js_dash/services/mavlink_service.dart';
import 'package:js_dash/services/mavlink_message_tracker.dart';

void main() {
  group('MavlinkService', () {
    late MavlinkService service;
    late MavlinkMessageTracker tracker;

    setUp(() {
      tracker = MavlinkMessageTracker();
      service = MavlinkService(tracker: tracker);
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

    test('should handle disconnect when not connected', () async {
      await expectLater(service.disconnect(), completes);
      expect(service.isConnected, isFalse);
    });

    test('should handle dispose without error', () {
      expect(() => service.dispose(), returnsNormally);
    });
  });
}
