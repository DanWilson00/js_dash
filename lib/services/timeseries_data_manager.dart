import 'dart:async';

import '../core/circular_buffer.dart';
import '../core/timeseries_point.dart';
import '../interfaces/disposable.dart';
import '../interfaces/i_data_repository.dart';
import '../interfaces/i_data_source.dart';
import '../mavlink/mavlink.dart';

import 'connection_manager.dart';
import 'generic_message_tracker.dart';
import 'settings_manager.dart';

class TimeSeriesDataManager implements IDataRepository, Disposable {
  TimeSeriesDataManager.injected(
    this._tracker,
    this._settingsManager, [
    this._connectionManager,
  ]) {
    if (_tracker != null) {
      _messageSubscription = _tracker!.statsStream.listen((messageStats) {
        _processMessageUpdates(messageStats);
      });
    }
    if (_settingsManager != null) {
      _updateFromSettings();
      _settingsManager!.addListener(_updateFromSettings);
    }
  }

  final Map<String, CircularBuffer> _dataBuffers = {};
  final StreamController<Map<String, CircularBuffer>> _dataController =
      StreamController<Map<String, CircularBuffer>>.broadcast();

  StreamSubscription? _messageSubscription;
  StreamSubscription? _dataSourceSubscription;
  StreamSubscription? _connectionStatusSubscription;
  GenericMessageTracker? _tracker;
  ConnectionManager? _connectionManager;
  bool _isTracking = false;
  bool _isPaused = false;
  bool _isInitialized = false;
  SettingsManager? _settingsManager;

  // Buffer configuration - defaults that can be overridden by settings
  int _currentBufferSize = 2000; // ~10 minutes at 3Hz, covers 5m window + margin
  Duration _currentMaxAge = const Duration(minutes: 10);

  // Performance optimizations
  static const int maxFieldCount = 500; // Limit field discovery to prevent unbounded growth

  @override
  Stream<Map<String, CircularBuffer>> get dataStream => _dataController.stream;

  /// Stream of message statistics from the internal tracker
  Stream<Map<String, GenericMessageStats>> get messageStatsStream =>
      _tracker?.statsStream ?? const Stream.empty();

  @override
  void startTracking([SettingsManager? settingsManager]) {
    if (_isTracking) return;
    _isTracking = true;

    // Set up settings manager if provided
    if (settingsManager != null) {
      _settingsManager = settingsManager;
      _updateFromSettings();
      settingsManager.addListener(_updateFromSettings);
    }

    // Note: _tracker should be injected, not created here
    // This method is kept for backward compatibility
    _tracker?.startTracking();
    if (_tracker != null) {
      _messageSubscription = _tracker!.statsStream.listen((messageStats) {
        _processMessageUpdates(messageStats);
      });
    }
  }

  void _updateFromSettings() {
    if (_settingsManager == null) return;

    final performance = _settingsManager!.performance;
    _currentBufferSize = performance.dataBufferSize;
    _currentMaxAge = Duration(minutes: performance.dataRetentionMinutes);

    // Note: Cannot dynamically resize existing CircularBuffers
    // New buffers will use the updated size
  }

  @override
  void stopTracking() {
    _isTracking = false;
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _tracker?.stopTracking();
    _settingsManager?.removeListener(_updateFromSettings);
    _settingsManager = null;
  }

  /// Track a message through the internal tracker
  /// This allows external sources to feed messages into the time series data
  void trackMessage(MavlinkMessage message) {
    _tracker?.trackMessage(message);
  }

  // ============================================================
  // Connection and Data Source Management (merged from TelemetryRepository)
  // ============================================================

  /// Initialize the data manager and set up data flow
  Future<void> initialize() async {
    if (_isInitialized) return;
    startTracking();
    _isInitialized = true;
  }

  /// Start listening to the current data source via connection manager
  Future<void> startListening() async {
    await initialize();

    if (_connectionManager == null) return;

    final currentDataSource = _connectionManager!.currentDataSource;
    if (currentDataSource != null) {
      await _subscribeToDataSource(currentDataSource);
    }

    // Listen for connection changes to update data source subscription
    _connectionStatusSubscription = _connectionManager!.statusStream.listen((status) {
      if (status.isConnected) {
        final newDataSource = _connectionManager!.currentDataSource;
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
    _connectionStatusSubscription?.cancel();
    _connectionStatusSubscription = null;
    stopTracking();
  }

  /// Subscribe to a specific data source
  Future<void> _subscribeToDataSource(IDataSource dataSource) async {
    // Unsubscribe from previous source first
    _unsubscribeFromDataSource();

    // Subscribe to the message stream and forward to tracker
    _dataSourceSubscription = dataSource.messageStream.listen((message) {
      if (!_isPaused) {
        trackMessage(message);
      }
    });
  }

  /// Unsubscribe from current data source
  void _unsubscribeFromDataSource() {
    _dataSourceSubscription?.cancel();
    _dataSourceSubscription = null;
  }

  /// Get current connection status
  bool get isConnected => _connectionManager?.currentStatus.isConnected ?? false;

  /// Get current data source
  IDataSource? get currentDataSource => _connectionManager?.currentDataSource;

  /// Connect using configuration (convenience method)
  Future<bool> connectWith(dynamic config) async {
    if (_connectionManager == null) return false;
    return await _connectionManager!.connect(config);
  }

  /// Disconnect (convenience method)
  Future<void> disconnect() async {
    await _connectionManager?.disconnect();
  }

  /// Pause connection (convenience method)
  void pauseConnection() {
    _connectionManager?.pause();
  }

  /// Resume connection (convenience method)
  void resumeConnection() {
    _connectionManager?.resume();
  }

  void _processMessageUpdates(Map<String, GenericMessageStats> messageStats) {
    if (_isPaused) return; // Don't process new data when paused

    final now = DateTime.now();
    bool hasNewData = false;
    final updatedBuffers = <String, CircularBuffer>{};

    for (final entry in messageStats.entries) {
      final messageName = entry.key;
      final stats = entry.value;

      if (stats.lastMessage != null) {
        // Extract raw numeric values directly from the message
        final rawFields = _extractRawMessageFields(stats.lastMessage!);

        for (final field in rawFields.entries) {
          final fieldKey = '$messageName.${field.key}';

          // Skip if we've reached field limit (prevent unbounded growth)
          if (_dataBuffers.length >= maxFieldCount && !_dataBuffers.containsKey(fieldKey)) {
            continue;
          }

          final value = field.value;
          if (value != null) {
            _dataBuffers.putIfAbsent(fieldKey, () => CircularBuffer(_currentBufferSize));
            _dataBuffers[fieldKey]!.add(TimeSeriesPoint(now, value));
            updatedBuffers[fieldKey] = _dataBuffers[fieldKey]!;
            hasNewData = true;
          }
        }
      }
    }

    // Clean up old data less frequently
    if (now.millisecondsSinceEpoch % 5000 < 200) { // Every ~5 seconds
      _cleanupOldData(now);
    }

    if (hasNewData && !_dataController.isClosed) {
      _dataController.add(Map.from(_dataBuffers));
    }
  }


  void _cleanupOldData(DateTime now) {
    final cutoff = now.subtract(_currentMaxAge);

    for (final buffer in _dataBuffers.values) {
      buffer.removeOldData(cutoff);
    }
  }

  /// Extract raw numeric fields from MavlinkMessage using metadata
  Map<String, double?> _extractRawMessageFields(MavlinkMessage message) {
    final fields = <String, double?>{};

    for (final entry in message.values.entries) {
      final value = entry.value;
      if (value is num) {
        fields[entry.key] = value.toDouble();
      } else if (value is List) {
        // For arrays, extract individual elements
        for (int i = 0; i < value.length; i++) {
          if (value[i] is num) {
            fields['${entry.key}[$i]'] = (value[i] as num).toDouble();
          }
        }
      }
    }

    return fields;
  }

  @override
  List<TimeSeriesPoint> getFieldData(String messageType, String fieldName) {
    final key = '$messageType.$fieldName';
    return _dataBuffers[key]?.points ?? [];
  }

  @override
  List<String> getAvailableFields() {
    return _dataBuffers.keys.toList()..sort();
  }

  @override
  void pause() {
    _isPaused = true;
    // Emit immediate event to notify listeners of pause state change
    if (!_dataController.isClosed) {
      _dataController.add(Map.from(_dataBuffers));
    }
  }

  @override
  void resume() {
    _isPaused = false;
    // Emit immediate event to notify listeners of pause state change
    if (!_dataController.isClosed) {
      _dataController.add(Map.from(_dataBuffers));
    }
  }

  @override
  bool get isPaused => _isPaused;

  @override
  void clearAllData() {
    _dataBuffers.clear();
    if (!_dataController.isClosed) {
      _dataController.add({});
    }
  }

  @override
  List<String> getFieldsForMessage(String messageType) {
    return _dataBuffers.keys
        .where((key) => key.startsWith('$messageType.'))
        .map((key) => key.substring(messageType.length + 1))
        .toList()
      ..sort();
  }


  @override
  void dispose() {
    _unsubscribeFromDataSource();
    _connectionStatusSubscription?.cancel();
    _connectionStatusSubscription = null;
    stopTracking();
    _dataBuffers.clear();
    if (!_dataController.isClosed) {
      _dataController.close();
    }
  }

  // Get current data state for debugging
  @override
  Map<String, int> getDataSummary() {
    return _dataBuffers.map((key, buffer) => MapEntry(key, buffer.length));
  }

  // For testing: inject synthetic data
  void injectTestData(String messageType, String fieldName, double value) {
    final key = '$messageType.$fieldName';
    final now = DateTime.now();
    final point = TimeSeriesPoint(now, value);

    _dataBuffers.putIfAbsent(key, () => CircularBuffer(_currentBufferSize));
    _dataBuffers[key]!.add(point);

    if (!_dataController.isClosed) {
      _dataController.add(Map.from(_dataBuffers));
    }
  }
}
