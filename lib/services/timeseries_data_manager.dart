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
  static const int defaultBufferSize = 2000; // ~10 minutes at 3Hz, covers 5m window + margin
  static const Duration maxAge = Duration(minutes: 10);
  
  // Performance optimizations
  static const int maxFieldCount = 500; // Limit field discovery to prevent unbounded growth
  final Map<String, double> _valueCache = {}; // Cache parsed values
  final Set<String> _numericFields = {}; // Cache known numeric fields
  final Set<String> _invalidFields = {}; // Cache known invalid fields
  final RegExp _numericRegex = RegExp(r'^-?\d*\.?\d+([eE][+-]?\d+)?$'); // Pre-compiled regex

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
    final updatedBuffers = <String, CircularBuffer>{};

    for (final entry in messageStats.entries) {
      final messageName = entry.key;
      final stats = entry.value;
      
      if (stats.lastMessage != null) {
        final fields = stats.getMessageFields();
        
        for (final field in fields.entries) {
          final fieldKey = '$messageName.${field.key}';
          
          // Skip if we've reached field limit (prevent unbounded growth)
          if (_dataBuffers.length >= maxFieldCount && !_dataBuffers.containsKey(fieldKey)) {
            continue;
          }
          
          // Skip if we know this field is invalid
          if (_invalidFields.contains(fieldKey)) {
            continue;
          }
          
          final value = _parseNumericValueOptimized(fieldKey, field.value);
          
          if (value != null) {
            _dataBuffers.putIfAbsent(fieldKey, () => CircularBuffer(defaultBufferSize));
            _dataBuffers[fieldKey]!.add(TimeSeriesPoint(now, value));
            updatedBuffers[fieldKey] = _dataBuffers[fieldKey]!;
            hasNewData = true;
            _numericFields.add(fieldKey); // Cache as numeric field
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

  double? _parseNumericValueOptimized(String fieldKey, dynamic value) {
    // Check cache first
    if (value is String) {
      final cacheKey = '${fieldKey}_$value';
      if (_valueCache.containsKey(cacheKey)) {
        return _valueCache[cacheKey];
      }
    }
    
    double? result;
    
    if (value is num) {
      result = value.toDouble();
    } else if (value is String) {
      // Quick check if we know this field type
      if (_numericFields.contains(fieldKey)) {
        // Fast path for known numeric fields
        if (_numericRegex.hasMatch(value)) {
          result = double.tryParse(value);
        } else {
          // Try removing units
          final cleaned = value.replaceAll(RegExp(r'[^\d\.\-eE\+]'), '');
          result = double.tryParse(cleaned);
        }
      } else {
        // Slower path for unknown fields
        // First try direct parse
        result = double.tryParse(value);
        
        // If that fails, try removing units
        if (result == null) {
          final cleaned = value.replaceAll(RegExp(r'[^\d\.\-eE\+]'), '');
          result = double.tryParse(cleaned);
        }
        
        // If still null, mark as invalid field
        if (result == null) {
          _invalidFields.add(fieldKey);
        }
      }
      
      // Cache the result for strings
      if (result != null) {
        final cacheKey = '${fieldKey}_$value';
        _valueCache[cacheKey] = result;
        
        // Limit cache size
        if (_valueCache.length > 1000) {
          _valueCache.clear();
        }
      }
    }
    
    return result;
  }

  void _cleanupOldData(DateTime now) {
    final cutoff = now.subtract(maxAge);
    
    for (final buffer in _dataBuffers.values) {
      buffer.removeOldData(cutoff);
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
    // Emit immediate event to notify listeners of pause state change
    if (!_dataController.isClosed) {
      _dataController.add(Map.from(_dataBuffers));
    }
  }
  
  void resume() {
    _isPaused = false;
    // Emit immediate event to notify listeners of pause state change  
    if (!_dataController.isClosed) {
      _dataController.add(Map.from(_dataBuffers));
    }
  }
  
  bool get isPaused => _isPaused;
  
  void clearAllData() {
    _dataBuffers.clear();
    _valueCache.clear();
    _numericFields.clear();
    _invalidFields.clear();
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