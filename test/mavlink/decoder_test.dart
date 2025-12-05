import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:js_dash/mavlink/mavlink.dart';

void main() {
  group('MavlinkMessageDecoder', () {
    late MavlinkMetadataRegistry registry;
    late MavlinkMessageDecoder decoder;

    setUp(() {
      registry = MavlinkMetadataRegistry();
      registry.loadFromJsonString('''
{
  "schema_version": "1.0.0",
  "enums": {
    "MAV_TYPE": {
      "name": "MAV_TYPE",
      "description": "Vehicle type",
      "bitmask": false,
      "entries": {
        "0": {"name": "MAV_TYPE_GENERIC", "value": 0, "description": "Generic"},
        "2": {"name": "MAV_TYPE_QUADROTOR", "value": 2, "description": "Quadrotor"}
      }
    }
  },
  "messages": {
    "0": {
      "id": 0,
      "name": "HEARTBEAT",
      "description": "Heartbeat",
      "crc_extra": 50,
      "encoded_length": 9,
      "fields": [
        {"name": "custom_mode", "type": "uint32_t", "base_type": "uint32_t", "offset": 0, "size": 4, "array_length": 1, "description": "", "extension": false},
        {"name": "type", "type": "uint8_t", "base_type": "uint8_t", "offset": 4, "size": 1, "array_length": 1, "enum": "MAV_TYPE", "description": "", "extension": false},
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
        {"name": "time_boot_ms", "type": "uint32_t", "base_type": "uint32_t", "offset": 0, "size": 4, "array_length": 1, "units": "ms", "description": "", "extension": false},
        {"name": "roll", "type": "float", "base_type": "float", "offset": 4, "size": 4, "array_length": 1, "units": "rad", "description": "", "extension": false},
        {"name": "pitch", "type": "float", "base_type": "float", "offset": 8, "size": 4, "array_length": 1, "units": "rad", "description": "", "extension": false},
        {"name": "yaw", "type": "float", "base_type": "float", "offset": 12, "size": 4, "array_length": 1, "units": "rad", "description": "", "extension": false},
        {"name": "rollspeed", "type": "float", "base_type": "float", "offset": 16, "size": 4, "array_length": 1, "units": "rad/s", "description": "", "extension": false},
        {"name": "pitchspeed", "type": "float", "base_type": "float", "offset": 20, "size": 4, "array_length": 1, "units": "rad/s", "description": "", "extension": false},
        {"name": "yawspeed", "type": "float", "base_type": "float", "offset": 24, "size": 4, "array_length": 1, "units": "rad/s", "description": "", "extension": false}
      ]
    },
    "253": {
      "id": 253,
      "name": "STATUSTEXT",
      "description": "Status text message",
      "crc_extra": 83,
      "encoded_length": 54,
      "fields": [
        {"name": "severity", "type": "uint8_t", "base_type": "uint8_t", "offset": 0, "size": 1, "array_length": 1, "description": "", "extension": false},
        {"name": "text", "type": "char[50]", "base_type": "char", "offset": 1, "size": 1, "array_length": 50, "description": "", "extension": false}
      ]
    }
  }
}
''');
      decoder = MavlinkMessageDecoder(registry);
    });

    MavlinkFrame _makeFrame(int msgId, Uint8List payload) {
      return MavlinkFrame(
        version: MavlinkVersion.v1,
        payloadLength: payload.length,
        incompatFlags: 0,
        compatFlags: 0,
        sequence: 1,
        systemId: 1,
        componentId: 1,
        messageId: msgId,
        payload: payload,
        receivedCrc: 0,
        calculatedCrc: 0,
      );
    }

    test('decodes HEARTBEAT message', () {
      // custom_mode=0x12345678, type=2, autopilot=3, base_mode=0x80, system_status=4, mavlink_version=3
      // Note: uint32_t is little-endian
      final payload = Uint8List.fromList([
        0x78, 0x56, 0x34, 0x12, // custom_mode (little-endian)
        0x02, // type
        0x03, // autopilot
        0x80, // base_mode
        0x04, // system_status
        0x03, // mavlink_version
      ]);

      final frame = _makeFrame(0, payload);
      final message = decoder.decode(frame);

      expect(message, isNotNull);
      expect(message!.name, equals('HEARTBEAT'));
      expect(message['custom_mode'], equals(0x12345678));
      expect(message['type'], equals(2));
      expect(message['autopilot'], equals(3));
      expect(message['base_mode'], equals(0x80));
      expect(message['system_status'], equals(4));
      expect(message['mavlink_version'], equals(3));
    });

    test('decodes ATTITUDE message with floats', () {
      // Create a ByteData to write little-endian floats
      final data = ByteData(28);
      data.setUint32(0, 1000, Endian.little); // time_boot_ms
      data.setFloat32(4, 0.5, Endian.little); // roll
      data.setFloat32(8, -0.3, Endian.little); // pitch
      data.setFloat32(12, 1.57, Endian.little); // yaw
      data.setFloat32(16, 0.1, Endian.little); // rollspeed
      data.setFloat32(20, 0.2, Endian.little); // pitchspeed
      data.setFloat32(24, 0.3, Endian.little); // yawspeed

      final payload = data.buffer.asUint8List();
      final frame = _makeFrame(30, payload);
      final message = decoder.decode(frame);

      expect(message, isNotNull);
      expect(message!.name, equals('ATTITUDE'));
      expect(message['time_boot_ms'], equals(1000));
      expect((message['roll'] as double).toStringAsFixed(1), equals('0.5'));
      expect((message['pitch'] as double).toStringAsFixed(1), equals('-0.3'));
    });

    test('decodes string field (STATUSTEXT)', () {
      final text = 'Hello World';
      final payload = Uint8List(54);
      payload[0] = 3; // severity
      // Copy text starting at offset 1
      for (int i = 0; i < text.length; i++) {
        payload[1 + i] = text.codeUnitAt(i);
      }
      // Rest is already 0 (null terminated)

      final frame = _makeFrame(253, payload);
      final message = decoder.decode(frame);

      expect(message, isNotNull);
      expect(message!.name, equals('STATUSTEXT'));
      expect(message['severity'], equals(3));
      expect(message['text'], equals('Hello World'));
    });

    test('returns null for unknown message ID', () {
      final payload = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
      final frame = _makeFrame(999, payload);
      final message = decoder.decode(frame);

      expect(message, isNull);
    });

    test('handles truncated payload gracefully', () {
      // Only 4 bytes instead of 9 for HEARTBEAT
      final payload = Uint8List.fromList([0x78, 0x56, 0x34, 0x12]);
      final frame = _makeFrame(0, payload);
      final message = decoder.decode(frame);

      expect(message, isNotNull);
      expect(message!['custom_mode'], equals(0x12345678));
      // Other fields should be missing
      expect(message.hasField('type'), isFalse);
    });
  });

  group('resolveEnumValues', () {
    test('resolves enum fields to names', () {
      final registry = MavlinkMetadataRegistry();
      registry.loadFromJsonString('''
{
  "schema_version": "1.0.0",
  "enums": {
    "MAV_TYPE": {
      "name": "MAV_TYPE",
      "description": "Vehicle type",
      "bitmask": false,
      "entries": {
        "2": {"name": "MAV_TYPE_QUADROTOR", "value": 2, "description": "Quadrotor"}
      }
    }
  },
  "messages": {
    "0": {
      "id": 0,
      "name": "HEARTBEAT",
      "description": "Heartbeat",
      "crc_extra": 50,
      "encoded_length": 9,
      "fields": [
        {"name": "custom_mode", "type": "uint32_t", "base_type": "uint32_t", "offset": 0, "size": 4, "array_length": 1, "description": "", "extension": false},
        {"name": "type", "type": "uint8_t", "base_type": "uint8_t", "offset": 4, "size": 1, "array_length": 1, "enum": "MAV_TYPE", "description": "", "extension": false}
      ]
    }
  }
}
''');

      final msgMeta = registry.getMessageById(0)!;
      final message = MavlinkMessage(
        id: 0,
        name: 'HEARTBEAT',
        metadata: msgMeta,
        values: {'custom_mode': 0, 'type': 2},
        systemId: 1,
        componentId: 1,
        sequence: 1,
      );

      final resolved = resolveEnumValues(message, registry);

      expect(resolved['custom_mode'], equals(0));
      expect(resolved['type'], equals('MAV_TYPE_QUADROTOR'));
    });
  });
}
