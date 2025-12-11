import 'package:flutter_test/flutter_test.dart';
import 'package:js_dash/mavlink/mavlink.dart';

void main() {
  group('MavlinkMetadataRegistry', () {
    late MavlinkMetadataRegistry registry;

    setUp(() {
      registry = MavlinkMetadataRegistry();
    });

    test('starts empty', () {
      expect(registry.isLoaded, isFalse);
      expect(registry.messageCount, equals(0));
      expect(registry.enumCount, equals(0));
    });

    test('loads metadata from JSON string', () {
      const json = '''
{
  "schema_version": "1.0.0",
  "generated_at": "2025-01-01T00:00:00Z",
  "dialect": {
    "name": "test",
    "version": 1
  },
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
      "description": "Heartbeat message",
      "crc_extra": 50,
      "encoded_length": 9,
      "fields": [
        {
          "name": "custom_mode",
          "type": "uint32_t",
          "base_type": "uint32_t",
          "offset": 0,
          "size": 4,
          "array_length": 1,
          "units": null,
          "enum": null,
          "description": "Custom mode",
          "extension": false
        },
        {
          "name": "type",
          "type": "uint8_t",
          "base_type": "uint8_t",
          "offset": 4,
          "size": 1,
          "array_length": 1,
          "units": null,
          "enum": "MAV_TYPE",
          "description": "Vehicle type",
          "extension": false
        }
      ]
    }
  }
}
''';

      registry.loadFromJsonString(json);

      expect(registry.isLoaded, isTrue);
      expect(registry.messageCount, equals(1));
      expect(registry.enumCount, equals(1));
      expect(registry.dialect?.name, equals('test'));
      expect(registry.schemaVersion, equals('1.0.0'));
    });

    test('looks up message by ID', () {
      const json = '''
{
  "schema_version": "1.0.0",
  "enums": {},
  "messages": {
    "30": {
      "id": 30,
      "name": "ATTITUDE",
      "description": "Attitude",
      "crc_extra": 39,
      "encoded_length": 28,
      "fields": []
    }
  }
}
''';

      registry.loadFromJsonString(json);

      final msg = registry.getMessageById(30);
      expect(msg, isNotNull);
      expect(msg!.name, equals('ATTITUDE'));
      expect(msg.crcExtra, equals(39));

      expect(registry.getMessageById(999), isNull);
    });

    test('looks up message by name', () {
      const json = '''
{
  "schema_version": "1.0.0",
  "enums": {},
  "messages": {
    "30": {
      "id": 30,
      "name": "ATTITUDE",
      "description": "Attitude",
      "crc_extra": 39,
      "encoded_length": 28,
      "fields": []
    }
  }
}
''';

      registry.loadFromJsonString(json);

      final msg = registry.getMessageByName('ATTITUDE');
      expect(msg, isNotNull);
      expect(msg!.id, equals(30));

      expect(registry.getMessageByName('UNKNOWN'), isNull);
    });

    test('resolves enum values', () {
      const json = '''
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
  "messages": {}
}
''';

      registry.loadFromJsonString(json);

      expect(registry.resolveEnumValue('MAV_TYPE', 0), equals('MAV_TYPE_GENERIC'));
      expect(registry.resolveEnumValue('MAV_TYPE', 2), equals('MAV_TYPE_QUADROTOR'));
      expect(registry.resolveEnumValue('MAV_TYPE', 99), isNull);
      expect(registry.resolveEnumValue('UNKNOWN', 0), isNull);
    });
  });

  group('MavlinkMessageMetadata', () {
    test('parses fields correctly', () {
      final json = {
        'id': 0,
        'name': 'HEARTBEAT',
        'description': 'Heartbeat',
        'crc_extra': 50,
        'encoded_length': 9,
        'fields': [
          {
            'name': 'custom_mode',
            'type': 'uint32_t',
            'base_type': 'uint32_t',
            'offset': 0,
            'size': 4,
            'array_length': 1,
            'units': null,
            'enum': null,
            'description': 'Custom mode',
            'extension': false,
          },
          {
            'name': 'type',
            'type': 'uint8_t',
            'base_type': 'uint8_t',
            'offset': 4,
            'size': 1,
            'array_length': 1,
            'units': null,
            'enum': 'MAV_TYPE',
            'description': 'Vehicle type',
            'extension': false,
          },
        ],
      };

      final msg = MavlinkMessageMetadata.fromJson(json);

      expect(msg.id, equals(0));
      expect(msg.name, equals('HEARTBEAT'));
      expect(msg.crcExtra, equals(50));
      expect(msg.fields.length, equals(2));

      final typeField = msg.getField('type');
      expect(typeField, isNotNull);
      expect(typeField!.enumType, equals('MAV_TYPE'));
      expect(typeField.offset, equals(4));
    });

    test('handles extension fields', () {
      final json = {
        'id': 1,
        'name': 'SYS_STATUS',
        'description': 'Status',
        'crc_extra': 124,
        'encoded_length': 31,
        'fields': [
          {
            'name': 'load',
            'type': 'uint16_t',
            'base_type': 'uint16_t',
            'offset': 0,
            'size': 2,
            'array_length': 1,
            'description': 'Load',
            'extension': false,
          },
          {
            'name': 'extended_field',
            'type': 'uint32_t',
            'base_type': 'uint32_t',
            'offset': 27,
            'size': 4,
            'array_length': 1,
            'description': 'Extended',
            'extension': true,
          },
        ],
      };

      final msg = MavlinkMessageMetadata.fromJson(json);

      expect(msg.nonExtensionFields.length, equals(1));
      expect(msg.extensionFields.length, equals(1));
      expect(msg.extensionFields.first.name, equals('extended_field'));
    });
  });
}
