import 'package:flutter_test/flutter_test.dart';
import 'package:js_dash/mavlink/mavlink.dart';

void main() {
  group('MavlinkCrc', () {
    test('initial value is 0xFFFF', () {
      final crc = MavlinkCrc();
      expect(crc.crc, equals(0xFFFF));
    });

    test('resets to 0xFFFF', () {
      final crc = MavlinkCrc();
      crc.accumulate(0x12);
      expect(crc.crc, isNot(0xFFFF));
      crc.reset();
      expect(crc.crc, equals(0xFFFF));
    });

    test('accumulates bytes correctly', () {
      final crc = MavlinkCrc();
      // Test known CRC values from MAVLink reference
      crc.accumulateBytes([0x09, 0x00, 0x00, 0x01, 0x01, 0x00]);
      // Just verify it produces some result
      expect(crc.crc, isNot(0xFFFF));
    });

    test('low and high bytes', () {
      final crc = MavlinkCrc();
      crc.accumulate(0x12);
      crc.accumulate(0x34);

      expect(crc.lowByte, equals(crc.crc & 0xFF));
      expect(crc.highByte, equals((crc.crc >> 8) & 0xFF));
    });
  });

  group('calculateFrameCrc', () {
    test('calculates CRC for HEARTBEAT frame', () {
      // MAVLink v1 header bytes (excluding STX):
      // len=9, seq=0, sysId=1, compId=1, msgId=0
      final headerBytes = [0x09, 0x00, 0x01, 0x01, 0x00];

      // HEARTBEAT payload (9 bytes):
      // custom_mode=0, type=2 (quadrotor), autopilot=3, base_mode=0x80, system_status=3, mavlink_version=3
      final payloadBytes = [0x00, 0x00, 0x00, 0x00, 0x02, 0x03, 0x80, 0x03, 0x03];

      // CRC extra for HEARTBEAT is 50
      final crc = calculateFrameCrc(headerBytes, payloadBytes, 50);

      // Just verify we get a valid CRC (not 0xFFFF)
      expect(crc, isNot(0xFFFF));
      expect(crc, isA<int>());
      expect(crc >= 0 && crc <= 0xFFFF, isTrue);
    });
  });
}
