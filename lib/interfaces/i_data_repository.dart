import 'dart:async';
import '../core/circular_buffer.dart';
import '../core/timeseries_point.dart';

/// Abstract interface for telemetry data access
/// Provides a clean abstraction for accessing time-series data
abstract interface class IDataRepository {
  /// Stream of all available telemetry data
  /// Map key is field identifier (e.g., "VFR_HUD.throttle")
  /// Map value is the circular buffer for that field
  Stream<Map<String, CircularBuffer>> get dataStream;

  /// Data access methods
  List<String> getAvailableFields();
  List<TimeSeriesPoint> getFieldData(String messageType, String fieldName);
  List<String> getFieldsForMessage(String messageType);

  /// Data management
  void clearAllData();
  bool get isPaused;
  void pause();
  void resume();

  /// Get summary of current data state (for debugging)
  Map<String, int> getDataSummary();

  /// Lifecycle management
  void startTracking();
  void stopTracking();
  void dispose();
}
