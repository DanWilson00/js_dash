import 'package:flutter_test/flutter_test.dart';
import 'package:js_dash/mavlink/mavlink.dart';
import 'package:js_dash/services/generic_message_tracker.dart';
import 'package:js_dash/services/timeseries_data_manager.dart';

void main() {
  group('TimeSeriesDataManager', () {
    late TimeSeriesDataManager dataManager;
    late MavlinkMetadataRegistry registry;
    late GenericMessageTracker tracker;

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
        {"name": "type", "type": "uint8_t", "base_type": "uint8_t", "offset": 4, "size": 1, "array_length": 1, "description": "", "extension": false}
      ]
    }
  }
}
''');
      tracker = GenericMessageTracker(registry);
      tracker.startTracking();
      dataManager = TimeSeriesDataManager.injected(tracker, null, null);
    });

    tearDown(() {
      dataManager.dispose();
      tracker.stopTracking();
    });

    test('should start and stop tracking', () {
      expect(dataManager.getAvailableFields(), isEmpty);

      dataManager.startTracking();
      expect(dataManager.getAvailableFields(), isEmpty); // No data yet

      dataManager.stopTracking();
      expect(dataManager.getAvailableFields(), isEmpty);
    });

    test('should clear data', () {
      dataManager.clearAllData();
      expect(dataManager.getAvailableFields(), isEmpty);
    });

    test('should provide data summary', () {
      final summary = dataManager.getDataSummary();
      expect(summary, isA<Map<String, int>>());
    });

    test('should get field data', () {
      final data = dataManager.getFieldData('HEARTBEAT', 'type');
      expect(data, isA<List>());
      expect(data, isEmpty);
    });

    test('should get fields for message', () {
      final fields = dataManager.getFieldsForMessage('HEARTBEAT');
      expect(fields, isA<List<String>>());
    });
  });
}
