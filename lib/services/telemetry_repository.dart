import 'dart:async';
import '../core/service_locator.dart';
import '../interfaces/i_data_source.dart';
import '../interfaces/i_data_repository.dart';
import '../models/plot_configuration.dart';
import '../services/connection_manager.dart';
import '../services/timeseries_data_manager.dart';

/// Centralized telemetry repository that unifies data access from various sources
/// This service provides a single pipeline for telemetry data processing,
/// eliminating duplication between TimeSeriesDataManager and direct data source access
class TelemetryRepository implements IDataRepository, Disposable {
  // Singleton support for backward compatibility - will be deprecated
  static TelemetryRepository? _instance;
  factory TelemetryRepository() => _instance ??= TelemetryRepository._internal();
  TelemetryRepository._internal();
  
  // New constructor for dependency injection
  TelemetryRepository.injected({
    ConnectionManager? connectionManager,
    TimeSeriesDataManager? timeSeriesManager,
  }) : _connectionManager = connectionManager,
       _timeSeriesManager = timeSeriesManager;
  
  // For testing - allows creating fresh instances
  TelemetryRepository.forTesting({
    ConnectionManager? connectionManager,
    TimeSeriesDataManager? timeSeriesManager,
  }) : _connectionManager = connectionManager,
       _timeSeriesManager = timeSeriesManager;

  ConnectionManager? _connectionManager;
  TimeSeriesDataManager? _timeSeriesManager;
  StreamSubscription? _dataSourceSubscription;
  bool _isInitialized = false;
  bool _isPaused = false;

  /// Get connection manager instance (DI or singleton fallback)
  ConnectionManager get _connManager {
    if (_connectionManager != null) return _connectionManager!;
    
    try {
      return GetIt.get<ConnectionManager>();
    } catch (e) {
      return ConnectionManager();
    }
  }

  /// Get time series manager instance (DI or singleton fallback)
  TimeSeriesDataManager get _tsManager {
    if (_timeSeriesManager != null) return _timeSeriesManager!;
    
    try {
      return GetIt.get<TimeSeriesDataManager>();
    } catch (e) {
      return TimeSeriesDataManager();
    }
  }

  /// Initialize the repository and set up data flow
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Ensure time series manager is initialized
    final tsManager = _tsManager;
    tsManager.startTracking();
    
    _isInitialized = true;
  }

  /// Start listening to the current data source via connection manager
  Future<void> startListening() async {
    await initialize();
    
    final connectionManager = _connManager;
    final currentDataSource = connectionManager.currentDataSource;
    
    if (currentDataSource != null) {
      await _subscribeToDataSource(currentDataSource);
    }
    
    // Listen for connection changes to update data source subscription
    connectionManager.statusStream.listen((status) {
      if (status.isConnected) {
        final newDataSource = connectionManager.currentDataSource;
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
    _tsManager.stopTracking();
  }

  /// Subscribe to a specific data source
  Future<void> _subscribeToDataSource(IDataSource dataSource) async {
    // Unsubscribe from previous source first
    _unsubscribeFromDataSource();
    
    // Subscribe to the message stream and forward to time series manager
    _dataSourceSubscription = dataSource.messageStream.listen((message) {
      if (!_isPaused) {
        // The time series manager will handle message processing
        // We just ensure it's tracking messages from this source
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
  Stream<Map<String, CircularBuffer>> get dataStream => _tsManager.dataStream;

  @override
  void startTracking([settingsManager]) {
    _tsManager.startTracking(settingsManager);
  }

  @override
  void stopTracking() {
    _tsManager.stopTracking();
  }

  @override
  List<TimeSeriesPoint> getFieldData(String messageType, String fieldName) {
    return _tsManager.getFieldData(messageType, fieldName);
  }

  @override
  List<String> getAvailableFields() {
    return _tsManager.getAvailableFields();
  }

  @override
  void pause() {
    _isPaused = true;
    _tsManager.pause();
  }

  @override
  void resume() {
    _isPaused = false;
    _tsManager.resume();
  }

  @override
  bool get isPaused => _isPaused;

  @override
  void clearAllData() {
    _tsManager.clearAllData();
  }

  @override
  List<String> getFieldsForMessage(String messageType) {
    return _tsManager.getFieldsForMessage(messageType);
  }

  @override
  Map<String, int> getDataSummary() {
    return _tsManager.getDataSummary();
  }

  /// Get current connection status
  bool get isConnected => _connManager.isConnected;

  /// Get current data source
  IDataSource? get currentDataSource => _connManager.currentDataSource;

  /// Connect using configuration (convenience method)
  Future<bool> connectWith(dynamic config) async {
    return await _connManager.connect(config);
  }

  /// Disconnect (convenience method)
  Future<void> disconnect() async {
    await _connManager.disconnect();
  }

  /// Pause connection (convenience method)
  void pauseConnection() {
    _connManager.pause();
  }

  /// Resume connection (convenience method)  
  void resumeConnection() {
    _connManager.resume();
  }

  @override
  void dispose() {
    stopListening();
    _unsubscribeFromDataSource();
  }

  // For testing - reset singleton instance
  static void resetInstanceForTesting() {
    _instance?.dispose();
    _instance = null;
  }
}