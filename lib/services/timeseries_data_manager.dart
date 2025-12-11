import 'dart:async';

import '../core/circular_buffer.dart';
import '../core/timeseries_point.dart';
import '../interfaces/disposable.dart';
import '../interfaces/i_data_repository.dart';
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
    // Note: Do NOT subscribe to statsStream here - let startTracking() handle it
    // to avoid double subscription if startTracking() is called later.
    if (_settingsManager != null) {
      _updateFromSettings();
      _settingsManager!.addListener(_updateFromSettings);
    }
  }

  final Map<String, CircularBuffer> _dataBuffers = {};
  final StreamController<Map<String, CircularBuffer>> _dataController =
      StreamController<Map<String, CircularBuffer>>.broadcast();

  StreamSubscription? _messageSubscription;
  StreamSubscription? _connectionStatusSubscription;
  final GenericMessageTracker? _tracker;
  final ConnectionManager? _connectionManager;
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
    final tracker = _tracker;
    tracker?.startTracking();
    if (tracker != null) {
      _messageSubscription = tracker.statsStream.listen((messageStats) {
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

  // ============================================================
  // Connection and Data Source Management
  // ============================================================

  /// Initialize the data manager and set up data flow
  Future<void> initialize() async {
    if (_isInitialized) return;
    startTracking();
    _isInitialized = true;
  }

  /// Start listening to connection status changes
  Future<void> startListening() async {
    await initialize();

    final connectionManager = _connectionManager;
    if (connectionManager == null) return;

    // Listen for connection changes - data flows through tracker.statsStream,
    // not directly through messageStream subscription
    _connectionStatusSubscription = connectionManager.statusStream.listen((status) {
      // Connection status changes are handled automatically through
      // the tracker which receives messages from MavlinkService
    });
  }

  /// Stop listening to connection status changes
  Future<void> stopListening() async {
    _connectionStatusSubscription?.cancel();
    _connectionStatusSubscription = null;
    stopTracking();
  }

  /// Get current connection status
  bool get isConnected => _connectionManager?.currentStatus.isConnected ?? false;


  /// Connect using configuration (convenience method)
  Future<bool> connectWith(dynamic config) async {
    final connectionManager = _connectionManager;
    if (connectionManager == null) return false;
    return await connectionManager.connect(config);
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
    // Also pause the connection manager to stop message flow at the source
    _connectionManager?.pause();
    // Emit immediate event to notify listeners of pause state change
    if (!_dataController.isClosed) {
      _dataController.add(Map.from(_dataBuffers));
    }
  }

  @override
  void resume() {
    _isPaused = false;
    // Also resume the connection manager to restart message flow
    _connectionManager?.resume();
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
