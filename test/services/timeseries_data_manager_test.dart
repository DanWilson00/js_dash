import 'package:flutter_test/flutter_test.dart';
import 'package:js_dash/services/timeseries_data_manager.dart';
import 'package:js_dash/services/mavlink_message_tracker.dart';

void main() {
  group('TimeSeriesDataManager', () {
    late TimeSeriesDataManager dataManager;

    setUp(() {
      TimeSeriesDataManager.resetInstanceForTesting();
      MavlinkMessageTracker.resetInstanceForTesting();
      dataManager = TimeSeriesDataManager();
    });

    tearDown(() {
      dataManager.dispose();
      TimeSeriesDataManager.resetInstanceForTesting();
      MavlinkMessageTracker.resetInstanceForTesting();
    });

    test('should be a singleton', () {
      final dataManager1 = TimeSeriesDataManager();
      final dataManager2 = TimeSeriesDataManager();
      expect(dataManager1, equals(dataManager2));
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
      final data = dataManager.getFieldData('HEARTBEAT', 'Type');
      expect(data, isA<List>());
      expect(data, isEmpty);
    });

    test('should get fields for message', () {
      final fields = dataManager.getFieldsForMessage('HEARTBEAT');
      expect(fields, isA<List<String>>());
    });
  });
}