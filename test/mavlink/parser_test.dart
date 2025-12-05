import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:js_dash/mavlink/mavlink.dart';

void main() {
  group('MavlinkFrameParser', () {
    late MavlinkMetadataRegistry registry;
    late MavlinkFrameParser parser;

    setUp(() {
      registry = MavlinkMetadataRegistry();
      // Minimal metadata for testing
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
    }
  }
}
''');
      parser = MavlinkFrameParser(registry);
    });

    tearDown(() {
      parser.dispose();
    });

    test('parses MAVLink v1 HEARTBEAT frame', () async {
      // Build a valid MAVLink v1 HEARTBEAT frame
      // STX=0xFE, len=9, seq=0, sysId=1, compId=1, msgId=0
      // payload: custom_mode=0, type=2, autopilot=3, base_mode=0x80, system_status=3, mavlink_version=3

      final headerBytes = [0x09, 0x00, 0x01, 0x01, 0x00];
      final payloadBytes = [0x00, 0x00, 0x00, 0x00, 0x02, 0x03, 0x80, 0x03, 0x03];

      // Calculate CRC
      final crc = calculateFrameCrc(headerBytes, payloadBytes, 50);

      // Build complete frame
      final frame = [
        0xFE, // STX
        ...headerBytes,
        ...payloadBytes,
        crc & 0xFF, // CRC low
        (crc >> 8) & 0xFF, // CRC high
      ];

      final frames = <MavlinkFrame>[];
      parser.stream.listen(frames.add);

      parser.parse(Uint8List.fromList(frame));

      // Allow async processing
      await Future.delayed(Duration.zero);

      expect(frames.length, equals(1));
      expect(frames.first.messageId, equals(0));
      expect(frames.first.systemId, equals(1));
      expect(frames.first.componentId, equals(1));
      expect(frames.first.payloadLength, equals(9));
      expect(frames.first.crcValid, isTrue);
      expect(frames.first.version, equals(MavlinkVersion.v1));
    });

    test('parses MAVLink v2 HEARTBEAT frame', () async {
      // Build a valid MAVLink v2 HEARTBEAT frame
      // STX=0xFD, len=9, incompat=0, compat=0, seq=0, sysId=1, compId=1, msgId=0 (3 bytes)

      final headerBytes = [0x09, 0x00, 0x00, 0x00, 0x01, 0x01, 0x00, 0x00, 0x00];
      final payloadBytes = [0x00, 0x00, 0x00, 0x00, 0x02, 0x03, 0x80, 0x03, 0x03];

      // Calculate CRC
      final crc = calculateFrameCrc(headerBytes, payloadBytes, 50);

      // Build complete frame
      final frame = [
        0xFD, // STX v2
        ...headerBytes,
        ...payloadBytes,
        crc & 0xFF,
        (crc >> 8) & 0xFF,
      ];

      final frames = <MavlinkFrame>[];
      parser.stream.listen(frames.add);

      parser.parse(Uint8List.fromList(frame));

      await Future.delayed(Duration.zero);

      expect(frames.length, equals(1));
      expect(frames.first.messageId, equals(0));
      expect(frames.first.version, equals(MavlinkVersion.v2));
      expect(frames.first.crcValid, isTrue);
    });

    test('handles byte-by-byte input', () async {
      final headerBytes = [0x09, 0x00, 0x01, 0x01, 0x00];
      final payloadBytes = [0x00, 0x00, 0x00, 0x00, 0x02, 0x03, 0x80, 0x03, 0x03];
      final crc = calculateFrameCrc(headerBytes, payloadBytes, 50);

      final frame = [
        0xFE,
        ...headerBytes,
        ...payloadBytes,
        crc & 0xFF,
        (crc >> 8) & 0xFF,
      ];

      final frames = <MavlinkFrame>[];
      parser.stream.listen(frames.add);

      // Feed bytes one at a time
      for (final byte in frame) {
        parser.parse(Uint8List.fromList([byte]));
      }

      await Future.delayed(Duration.zero);

      expect(frames.length, equals(1));
      expect(frames.first.crcValid, isTrue);
    });

    test('handles multiple frames in sequence', () async {
      final headerBytes = [0x09, 0x00, 0x01, 0x01, 0x00];
      final payloadBytes = [0x00, 0x00, 0x00, 0x00, 0x02, 0x03, 0x80, 0x03, 0x03];
      final crc = calculateFrameCrc(headerBytes, payloadBytes, 50);

      final frame = [
        0xFE,
        ...headerBytes,
        ...payloadBytes,
        crc & 0xFF,
        (crc >> 8) & 0xFF,
      ];

      // Send 3 frames
      final multiFrame = [...frame, ...frame, ...frame];

      final frames = <MavlinkFrame>[];
      parser.stream.listen(frames.add);

      parser.parse(Uint8List.fromList(multiFrame));

      await Future.delayed(Duration.zero);

      expect(frames.length, equals(3));
    });

    test('rejects frames with invalid CRC', () async {
      final headerBytes = [0x09, 0x00, 0x01, 0x01, 0x00];
      final payloadBytes = [0x00, 0x00, 0x00, 0x00, 0x02, 0x03, 0x80, 0x03, 0x03];

      // Use wrong CRC
      final frame = [
        0xFE,
        ...headerBytes,
        ...payloadBytes,
        0xFF, // Wrong CRC
        0xFF,
      ];

      final frames = <MavlinkFrame>[];
      parser.stream.listen(frames.add);

      parser.parse(Uint8List.fromList(frame));

      await Future.delayed(Duration.zero);

      expect(frames.length, equals(0));
      expect(parser.crcErrors, equals(1));
    });

    test('ignores unknown message IDs', () async {
      // Build a frame with unknown message ID 999
      final headerBytes = [0x09, 0x00, 0x01, 0x01, 0xE7]; // msgId = 231 (unknown)
      final payloadBytes = [0x00, 0x00, 0x00, 0x00, 0x02, 0x03, 0x80, 0x03, 0x03];
      final crc = calculateFrameCrc(headerBytes, payloadBytes, 0); // Arbitrary CRC

      final frame = [
        0xFE,
        ...headerBytes,
        ...payloadBytes,
        crc & 0xFF,
        (crc >> 8) & 0xFF,
      ];

      final frames = <MavlinkFrame>[];
      parser.stream.listen(frames.add);

      parser.parse(Uint8List.fromList(frame));

      await Future.delayed(Duration.zero);

      expect(frames.length, equals(0));
      expect(parser.unknownMessages, equals(1));
    });

    test('skips garbage bytes before STX', () async {
      final headerBytes = [0x09, 0x00, 0x01, 0x01, 0x00];
      final payloadBytes = [0x00, 0x00, 0x00, 0x00, 0x02, 0x03, 0x80, 0x03, 0x03];
      final crc = calculateFrameCrc(headerBytes, payloadBytes, 50);

      // Garbage bytes + valid frame
      final data = [
        0x12, 0x34, 0x56, 0x78, // garbage
        0xFE,
        ...headerBytes,
        ...payloadBytes,
        crc & 0xFF,
        (crc >> 8) & 0xFF,
      ];

      final frames = <MavlinkFrame>[];
      parser.stream.listen(frames.add);

      parser.parse(Uint8List.fromList(data));

      await Future.delayed(Duration.zero);

      expect(frames.length, equals(1));
      expect(frames.first.crcValid, isTrue);
    });
  });
}
