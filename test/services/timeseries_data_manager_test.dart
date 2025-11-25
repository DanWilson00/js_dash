import 'package:flutter_test/flutter_test.dart';
import 'package:js_dash/services/timeseries_data_manager.dart';

void main() {
  group('TimeSeriesDataManager', () {
    late TimeSeriesDataManager dataManager;

    setUp(() {
      // Use the default constructor which is now safe or the injected one if needed
      // For this test, we can use the default one but we should ensure we don't rely on shared state
      TimeSeriesDataManager.resetInstanceForTesting();
      dataManager = TimeSeriesDataManager();
    });

    tearDown(() {
      dataManager.dispose();
      TimeSeriesDataManager.resetInstanceForTesting();
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
