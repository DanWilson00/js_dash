import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_mavlink/dialects/common.dart';
import 'package:js_dash/services/mavlink_spoof_service.dart';

void main() {
  group('MavlinkSpoofService', () {
    late MavlinkSpoofService service;
    late List<StreamSubscription> subscriptions;

    setUp(() {
      MavlinkSpoofService.resetInstanceForTesting();
      service = MavlinkSpoofService.forTesting();
      subscriptions = [];
    });

    tearDown(() {
      service.stopSpoofing();
      for (var subscription in subscriptions) {
        subscription.cancel();
      }
      service.dispose();
      MavlinkSpoofService.resetInstanceForTesting();
    });

    test('should be a singleton', () {
      final service1 = MavlinkSpoofService();
      final service2 = MavlinkSpoofService();
      expect(service1, equals(service2));
    });

    test('should have correct initial state', () {
      expect(service.isRunning, isFalse);
    });

    test('should provide stream access', () {
      expect(service.heartbeatStream, isA<Stream<Heartbeat>>());
      expect(service.sysStatusStream, isA<Stream<SysStatus>>());
      expect(service.attitudeStream, isA<Stream<Attitude>>());
      expect(service.gpsStream, isA<Stream<GlobalPositionInt>>());
      expect(service.vfrHudStream, isA<Stream<VfrHud>>());
    });

    test('should start spoofing', () {
      service.startSpoofing();
      expect(service.isRunning, isTrue);
    });

    test('should stop spoofing', () {
      service.startSpoofing();
      expect(service.isRunning, isTrue);
      
      service.stopSpoofing();
      expect(service.isRunning, isFalse);
    });

    test('should not start twice', () {
      service.startSpoofing();
      expect(service.isRunning, isTrue);
      
      service.startSpoofing(); // Should not start again
      expect(service.isRunning, isTrue);
    });

    test('should generate heartbeat messages', () async {
      final completer = Completer<Heartbeat>();
      
      subscriptions.add(
        service.heartbeatStream.listen((heartbeat) {
          if (!completer.isCompleted) {
            completer.complete(heartbeat);
          }
        }),
      );
      
      service.startSpoofing(interval: const Duration(milliseconds: 100));
      
      final heartbeat = await completer.future.timeout(const Duration(seconds: 2));
      expect(heartbeat.type, equals(mavTypeSubmarine));
      expect(heartbeat.autopilot, equals(mavAutopilotArdupilotmega));
      expect(heartbeat.systemStatus, equals(mavStateActive));
    });

    test('should generate attitude messages', () async {
      final completer = Completer<Attitude>();
      
      subscriptions.add(
        service.attitudeStream.listen((attitude) {
          if (!completer.isCompleted) {
            completer.complete(attitude);
          }
        }),
      );
      
      service.startSpoofing(interval: const Duration(milliseconds: 100));
      
      final attitude = await completer.future.timeout(const Duration(seconds: 2));
      expect(attitude.roll, isA<double>());
      expect(attitude.pitch, isA<double>());
      expect(attitude.yaw, isA<double>());
    });

    test('should generate GPS messages', () async {
      final completer = Completer<GlobalPositionInt>();
      
      subscriptions.add(
        service.gpsStream.listen((gps) {
          if (!completer.isCompleted) {
            completer.complete(gps);
          }
        }),
      );
      
      service.startSpoofing(interval: const Duration(milliseconds: 100));
      
      final gps = await completer.future.timeout(const Duration(seconds: 2));
      expect(gps.lat, isA<int>());
      expect(gps.lon, isA<int>());
      expect(gps.alt, isA<int>());
    });

    test('should generate system status messages', () async {
      final completer = Completer<SysStatus>();
      
      subscriptions.add(
        service.sysStatusStream.listen((sysStatus) {
          if (!completer.isCompleted) {
            completer.complete(sysStatus);
          }
        }),
      );
      
      service.startSpoofing(interval: const Duration(milliseconds: 100));
      
      final sysStatus = await completer.future.timeout(const Duration(seconds: 2));
      expect(sysStatus.voltageBattery, isA<int>());
      expect(sysStatus.batteryRemaining, isA<int>());
      expect(sysStatus.batteryRemaining, greaterThanOrEqualTo(50));
      expect(sysStatus.batteryRemaining, lessThanOrEqualTo(100));
    });

    test('should generate VFR HUD messages', () async {
      final completer = Completer<VfrHud>();
      
      subscriptions.add(
        service.vfrHudStream.listen((vfrHud) {
          if (!completer.isCompleted) {
            completer.complete(vfrHud);
          }
        }),
      );
      
      service.startSpoofing(interval: const Duration(milliseconds: 100));
      
      final vfrHud = await completer.future.timeout(const Duration(seconds: 2));
      expect(vfrHud.airspeed, isA<double>());
      expect(vfrHud.groundspeed, isA<double>());
      expect(vfrHud.heading, isA<int>());
      expect(vfrHud.throttle, isA<int>());
    });

    test('should handle dispose without error', () {
      service.startSpoofing();
      expect(() => service.dispose(), returnsNormally);
      expect(service.isRunning, isFalse);
    });
  });
}