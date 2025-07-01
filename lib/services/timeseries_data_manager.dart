import 'dart:async';
import '../models/plot_configuration.dart';
import 'mavlink_message_tracker.dart';

class TimeSeriesDataManager {
  static TimeSeriesDataManager? _instance;
  factory TimeSeriesDataManager() => _instance ??= TimeSeriesDataManager._internal();
  TimeSeriesDataManager._internal();

  final Map<String, CircularBuffer> _dataBuffers = {};
  final StreamController<Map<String, CircularBuffer>> _dataController = 
      StreamController<Map<String, CircularBuffer>>.broadcast();
  
  StreamSubscription? _messageSubscription;
  bool _isTracking = false;
  bool _isPaused = false;

  // Buffer configuration
  static const int defaultBufferSize = 1000; // ~5 minutes at 3Hz
  static const Duration maxAge = Duration(minutes: 10);

  Stream<Map<String, CircularBuffer>> get dataStream => _dataController.stream;

  void startTracking() {
    if (_isTracking) return;
    _isTracking = true;

    final tracker = MavlinkMessageTracker();
    _messageSubscription = tracker.statsStream.listen((messageStats) {
      _processMessageUpdates(messageStats);
    });
  }

  void stopTracking() {
    _isTracking = false;
    _messageSubscription?.cancel();
    _messageSubscription = null;
  }

  void _processMessageUpdates(Map<String, MessageStats> messageStats) {
    if (_isPaused) return; // Don't process new data when paused
    
    final now = DateTime.now();
    bool hasNewData = false;

    for (final entry in messageStats.entries) {
      final messageName = entry.key;
      final stats = entry.value;
      
      if (stats.lastMessage != null) {
        final fields = stats.getMessageFields();
        
        for (final field in fields.entries) {
          final fieldKey = '$messageName.${field.key}';
          final value = _parseNumericValue(field.value);
          
          if (value != null) {
            _dataBuffers.putIfAbsent(fieldKey, () => CircularBuffer(defaultBufferSize));
            _dataBuffers[fieldKey]!.add(TimeSeriesPoint(now, value));
            hasNewData = true;
          }
        }
      }
    }

    // Clean up old data
    _cleanupOldData(now);

    if (hasNewData && !_dataController.isClosed) {
      _dataController.add(Map.from(_dataBuffers));
    }
  }

  double? _parseNumericValue(dynamic value) {
    if (value is num) return value.toDouble();
    
    if (value is String) {
      // Remove units and parse
      final cleaned = value.replaceAll(RegExp(r'[^\d\.\-]'), '');
      return double.tryParse(cleaned);
    }
    
    return null;
  }

  void _cleanupOldData(DateTime now) {
    final cutoff = now.subtract(maxAge);
    
    for (final buffer in _dataBuffers.values) {
      while (buffer.points.isNotEmpty && 
             buffer.points.first.timestamp.isBefore(cutoff)) {
        buffer.points.removeAt(0);
      }
    }
  }

  List<TimeSeriesPoint> getFieldData(String messageType, String fieldName) {
    final key = '$messageType.$fieldName';
    return _dataBuffers[key]?.points ?? [];
  }

  List<String> getAvailableFields() {
    return _dataBuffers.keys.toList()..sort();
  }
  
  void pause() {
    _isPaused = true;
  }
  
  void resume() {
    _isPaused = false;
  }
  
  bool get isPaused => _isPaused;
  
  void clearAllData() {
    _dataBuffers.clear();
    if (!_dataController.isClosed) {
      _dataController.add({});
    }
  }

  List<String> getFieldsForMessage(String messageType) {
    return _dataBuffers.keys
        .where((key) => key.startsWith('$messageType.'))
        .map((key) => key.substring(messageType.length + 1))
        .toList()
      ..sort();
  }

  void clearData() {
    _dataBuffers.clear();
    if (!_dataController.isClosed) {
      _dataController.add({});
    }
  }

  void dispose() {
    stopTracking();
    _dataBuffers.clear();
    if (!_dataController.isClosed) {
      _dataController.close();
    }
  }

  // For testing
  static void resetInstanceForTesting() {
    _instance?.dispose();
    _instance = null;
  }

  // Get current data state for debugging
  Map<String, int> getDataSummary() {
    return _dataBuffers.map((key, buffer) => MapEntry(key, buffer.length));
  }

  // For testing: inject synthetic data
  void injectTestData(String messageType, String fieldName, double value) {
    final key = '$messageType.$fieldName';
    final now = DateTime.now();
    final point = TimeSeriesPoint(now, value);
    
    _dataBuffers.putIfAbsent(key, () => CircularBuffer(defaultBufferSize));
    _dataBuffers[key]!.add(point);
    
    if (!_dataController.isClosed) {
      _dataController.add(Map.from(_dataBuffers));
    }
  }
}