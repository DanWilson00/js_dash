import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_mavlink/dialects/common.dart';
import 'package:js_dash/services/mavlink_message_tracker.dart';

void main() {
  group('MavlinkMessageTracker', () {
    late MavlinkMessageTracker tracker;

    setUp(() {
      tracker = MavlinkMessageTracker();
    });

    tearDown(() {
      tracker.dispose();
    });

    test('should start and stop tracking', () {
      expect(tracker.currentStats, isEmpty);

      tracker.startTracking();
      expect(tracker.currentStats, isEmpty); // No messages yet

      tracker.stopTracking();
      expect(tracker.currentStats, isEmpty);
    });

    test('should track heartbeat messages', () async {
      tracker.startTracking();

      final heartbeat = Heartbeat(
        type: mavTypeSubmarine,
        autopilot: mavAutopilotArdupilotmega,
        baseMode: mavModeFlagSafetyArmed,
        customMode: 0,
        systemStatus: mavStateActive,
        mavlinkVersion: 3,
      );

      tracker.trackMessage(heartbeat);

      final stats = tracker.currentStats;
      expect(stats.containsKey('HEARTBEAT'), isTrue);
      expect(stats['HEARTBEAT']!.count, equals(1));
      expect(stats['HEARTBEAT']!.lastMessage, equals(heartbeat));
    });

    test('should track multiple message types', () {
      tracker.startTracking();

      final heartbeat = Heartbeat(
        type: mavTypeSubmarine,
        autopilot: mavAutopilotArdupilotmega,
        baseMode: mavModeFlagSafetyArmed,
        customMode: 0,
        systemStatus: mavStateActive,
        mavlinkVersion: 3,
      );

      final attitude = Attitude(
        timeBootMs: 1000,
        roll: 0.1,
        pitch: 0.2,
        yaw: 0.3,
        rollspeed: 0.01,
        pitchspeed: 0.02,
        yawspeed: 0.03,
      );

      tracker.trackMessage(heartbeat);
      tracker.trackMessage(attitude);

      final stats = tracker.currentStats;
      expect(stats.length, equals(2));
      expect(stats.containsKey('HEARTBEAT'), isTrue);
      expect(stats.containsKey('ATTITUDE'), isTrue);
    });

    test('should increment count for repeated messages', () {
      tracker.startTracking();

      final heartbeat = Heartbeat(
        type: mavTypeSubmarine,
        autopilot: mavAutopilotArdupilotmega,
        baseMode: mavModeFlagSafetyArmed,
        customMode: 0,
        systemStatus: mavStateActive,
        mavlinkVersion: 3,
      );

      tracker.trackMessage(heartbeat);
      tracker.trackMessage(heartbeat);
      tracker.trackMessage(heartbeat);

      final stats = tracker.currentStats['HEARTBEAT']!;
      expect(stats.count, equals(3));
    });

    test('should provide message fields for heartbeat', () {
      tracker.startTracking();

      final heartbeat = Heartbeat(
        type: mavTypeSubmarine,
        autopilot: mavAutopilotArdupilotmega,
        baseMode: mavModeFlagSafetyArmed,
        customMode: 42,
        systemStatus: mavStateActive,
        mavlinkVersion: 3,
      );

      tracker.trackMessage(heartbeat);

      final fields = tracker.currentStats['HEARTBEAT']!.getMessageFields();
      expect(fields['Type'], equals('Submarine'));
      expect(fields['Autopilot'], equals('ArduPilot'));
      expect(fields['Custom Mode'], equals('42'));
      expect(fields['MAVLink Version'], equals('3'));
    });

    test('should provide message fields for attitude', () {
      tracker.startTracking();

      final attitude = Attitude(
        timeBootMs: 1000,
        roll: 0.1,
        pitch: 0.2,
        yaw: 0.3,
        rollspeed: 0.01,
        pitchspeed: 0.02,
        yawspeed: 0.03,
      );

      tracker.trackMessage(attitude);

      final fields = tracker.currentStats['ATTITUDE']!.getMessageFields();
      expect(fields.containsKey('Roll'), isTrue);
      expect(fields.containsKey('Pitch'), isTrue);
      expect(fields.containsKey('Yaw'), isTrue);
      expect(fields['Time Boot'], equals('1000 ms'));
    });

    test('should provide message fields for GPS', () {
      tracker.startTracking();

      final gps = GlobalPositionInt(
        timeBootMs: 2000,
        lat: 377749000, // 37.7749 degrees * 1e7
        lon: -1224194000, // -122.4194 degrees * 1e7
        alt: 10000, // 10 meters * 1000
        relativeAlt: 5000,
        vx: 150, // 1.5 m/s * 100
        vy: -200,
        vz: 50,
        hdg: 9000, // 90 degrees * 100
      );

      tracker.trackMessage(gps);

      final fields = tracker.currentStats['GLOBAL_POSITION_INT']!
          .getMessageFields();
      expect(fields['Latitude'], equals('37.7749°'));
      expect(fields['Longitude'], equals('-122.4194°'));
      expect(fields['Altitude'], equals('10.0 m'));
      expect(fields['Heading'], equals('90.0°'));
    });

    test('should emit stats updates via stream', () async {
      final completer = Completer<Map<String, MessageStats>>();

      tracker.startTracking();

      tracker.statsStream.listen((stats) {
        if (stats.isNotEmpty && !completer.isCompleted) {
          completer.complete(stats);
        }
      });

      final heartbeat = Heartbeat(
        type: mavTypeSubmarine,
        autopilot: mavAutopilotArdupilotmega,
        baseMode: mavModeFlagSafetyArmed,
        customMode: 0,
        systemStatus: mavStateActive,
        mavlinkVersion: 3,
      );

      tracker.trackMessage(heartbeat);

      final stats = await completer.future.timeout(const Duration(seconds: 2));
      expect(stats.containsKey('HEARTBEAT'), isTrue);
    });

    test('should clear stats', () {
      tracker.startTracking();

      final heartbeat = Heartbeat(
        type: mavTypeSubmarine,
        autopilot: mavAutopilotArdupilotmega,
        baseMode: mavModeFlagSafetyArmed,
        customMode: 0,
        systemStatus: mavStateActive,
        mavlinkVersion: 3,
      );

      tracker.trackMessage(heartbeat);
      expect(tracker.currentStats.isNotEmpty, isTrue);

      tracker.clearStats();
      expect(tracker.currentStats.isEmpty, isTrue);
    });

    test('should ignore messages when not tracking', () {
      // Don't start tracking
      final heartbeat = Heartbeat(
        type: mavTypeSubmarine,
        autopilot: mavAutopilotArdupilotmega,
        baseMode: mavModeFlagSafetyArmed,
        customMode: 0,
        systemStatus: mavStateActive,
        mavlinkVersion: 3,
      );

      tracker.trackMessage(heartbeat);
      expect(tracker.currentStats.isEmpty, isTrue);
    });
  });

  group('MessageStats', () {
    test('should update message correctly', () {
      final stats = MessageStats();
      final heartbeat = Heartbeat(
        type: mavTypeSubmarine,
        autopilot: mavAutopilotArdupilotmega,
        baseMode: mavModeFlagSafetyArmed,
        customMode: 0,
        systemStatus: mavStateActive,
        mavlinkVersion: 3,
      );

      stats.updateMessage(heartbeat);

      expect(stats.count, equals(1));
      expect(stats.lastMessage, equals(heartbeat));
      expect(stats.frequency, isA<double>());
    });

    test('should handle unknown message types', () {
      final stats = MessageStats();
      stats.lastMessage = null;

      final fields = stats.getMessageFields();
      expect(fields.isEmpty, isTrue);
    });
  });
}
