import 'dart:async';
import '../interfaces/i_data_source.dart';
import '../interfaces/i_data_repository.dart';
import '../core/circular_buffer.dart';
import '../core/timeseries_point.dart';
import '../services/connection_manager.dart';
import '../services/timeseries_data_manager.dart';
import '../services/mavlink_message_tracker.dart';
import '../interfaces/disposable.dart';

/// Centralized telemetry repository that unifies data access from various sources
/// This service provides a single pipeline for telemetry data processing,
/// eliminating duplication between TimeSeriesDataManager and direct data source access
class TelemetryRepository implements IDataRepository, Disposable {
  // Removed Singleton - use Dependency Injection

  // New constructor for dependency injection
  TelemetryRepository({
    required ConnectionManager connectionManager,
    required TimeSeriesDataManager timeSeriesManager,
  }) : _connectionManager = connectionManager,
       _timeSeriesManager = timeSeriesManager;

  // For testing - allows creating fresh instances
  TelemetryRepository.forTesting({
    required ConnectionManager connectionManager,
    required TimeSeriesDataManager timeSeriesManager,
  }) : _connectionManager = connectionManager,
       _timeSeriesManager = timeSeriesManager;

  final ConnectionManager _connectionManager;
  final TimeSeriesDataManager _timeSeriesManager;
  StreamSubscription? _dataSourceSubscription;
  bool _isInitialized = false;
  bool _isPaused = false;

  /// Initialize the repository and set up data flow
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Ensure time series manager is initialized
    _timeSeriesManager.startTracking();

    _isInitialized = true;
  }

  /// Start listening to the current data source via connection manager
  Future<void> startListening() async {
    await initialize();

    final currentDataSource = _connectionManager.currentDataSource;

    if (currentDataSource != null) {
      await _subscribeToDataSource(currentDataSource);
    }

    // Listen for connection changes to update data source subscription
    _connectionManager.statusStream.listen((status) {
      if (status.isConnected) {
        final newDataSource = _connectionManager.currentDataSource;
        if (newDataSource != null) {
          _subscribeToDataSource(newDataSource);
        }
      } else {
        _unsubscribeFromDataSource();
      }
    });
  }

  /// Stop listening to data sources
  Future<void> stopListening() async {
    _unsubscribeFromDataSource();
    _timeSeriesManager.stopTracking();
  }

  /// Subscribe to a specific data source
  Future<void> _subscribeToDataSource(IDataSource dataSource) async {
    // Unsubscribe from previous source first
    _unsubscribeFromDataSource();

    // Subscribe to the message stream and forward to time series manager
    _dataSourceSubscription = dataSource.messageStream.listen((message) {
      if (!_isPaused) {
        // Forward the message to the time series manager for storage
        _timeSeriesManager.trackMessage(message);
      }
    });
  }

  /// Unsubscribe from current data source
  void _unsubscribeFromDataSource() {
    _dataSourceSubscription?.cancel();
    _dataSourceSubscription = null;
  }

  // Delegate IDataRepository methods to TimeSeriesDataManager

  @override
  Stream<Map<String, CircularBuffer>> get dataStream =>
      _timeSeriesManager.dataStream;

  /// Stream of message statistics from the time series manager
  Stream<Map<String, MessageStats>> get messageStatsStream =>
      _timeSeriesManager.messageStatsStream;

  @override
  void startTracking([dynamic settingsManager]) {
    _timeSeriesManager.startTracking(settingsManager);
  }

  @override
  void stopTracking() {
    _timeSeriesManager.stopTracking();
  }

  @override
  List<TimeSeriesPoint> getFieldData(String messageType, String fieldName) {
    return _timeSeriesManager.getFieldData(messageType, fieldName);
  }

  @override
  List<String> getAvailableFields() {
    return _timeSeriesManager.getAvailableFields();
  }

  @override
  void pause() {
    _isPaused = true;
    _timeSeriesManager.pause();
  }

  @override
  void resume() {
    _isPaused = false;
    _timeSeriesManager.resume();
  }

  @override
  bool get isPaused => _isPaused;

  @override
  void clearAllData() {
    _timeSeriesManager.clearAllData();
  }

  @override
  List<String> getFieldsForMessage(String messageType) {
    return _timeSeriesManager.getFieldsForMessage(messageType);
  }

  @override
  Map<String, int> getDataSummary() {
    return _timeSeriesManager.getDataSummary();
  }

  /// Get current connection status
  bool get isConnected => _connectionManager.currentStatus.isConnected;

  /// Get current data source
  IDataSource? get currentDataSource => _connectionManager.currentDataSource;

  /// Connect using configuration (convenience method)
  Future<bool> connectWith(dynamic config) async {
    return await _connectionManager.connect(config);
  }

  /// Disconnect (convenience method)
  Future<void> disconnect() async {
    await _connectionManager.disconnect();
  }

  /// Pause connection (convenience method)
  void pauseConnection() {
    _connectionManager.pause();
  }

  /// Resume connection (convenience method)
  void resumeConnection() {
    _connectionManager.resume();
  }

  @override
  void dispose() {
    stopListening();
    _unsubscribeFromDataSource();
  }

  // For testing - reset singleton instance
  static void resetInstanceForTesting() {
    // No singleton to reset
  }
}
