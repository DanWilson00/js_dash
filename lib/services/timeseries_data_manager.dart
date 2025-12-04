import 'dart:async';
import 'package:dart_mavlink/mavlink_message.dart';
import 'package:dart_mavlink/dialects/common.dart';
import '../core/circular_buffer.dart';
import '../core/timeseries_point.dart';
import '../interfaces/disposable.dart';
import '../interfaces/i_data_repository.dart';

import 'mavlink_message_tracker.dart';
import 'settings_manager.dart';

class TimeSeriesDataManager implements IDataRepository, Disposable {
  TimeSeriesDataManager.injected(this._tracker, this._settingsManager) {
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
  MavlinkMessageTracker? _tracker;
  bool _isTracking = false;
  bool _isPaused = false;
  SettingsManager? _settingsManager;

  // Buffer configuration - defaults that can be overridden by settings
  int _currentBufferSize = 2000; // ~10 minutes at 3Hz, covers 5m window + margin
  Duration _currentMaxAge = const Duration(minutes: 10);
  
  // Performance optimizations
  static const int maxFieldCount = 500; // Limit field discovery to prevent unbounded growth

  @override
  Stream<Map<String, CircularBuffer>> get dataStream => _dataController.stream;
  
  /// Stream of message statistics from the internal tracker
  Stream<Map<String, MessageStats>> get messageStatsStream => _tracker?.statsStream ?? const Stream.empty();

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

    _tracker = MavlinkMessageTracker();
    _tracker!.startTracking();
    _messageSubscription = _tracker!.statsStream.listen((messageStats) {
      _processMessageUpdates(messageStats);
    });
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
    _tracker = null;
    _settingsManager?.removeListener(_updateFromSettings);
    _settingsManager = null;
  }
  
  /// Track a message through the internal tracker
  /// This allows external sources to feed messages into the time series data
  void trackMessage(MavlinkMessage message) {
    _tracker?.trackMessage(message);
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
        // Extract raw numeric values directly from the MAVLink message for dashboard
        final rawFields = _extractRawMessageFields(messageName, stats.lastMessage!);
        
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
        
        // Also extract formatted fields for backward compatibility with plotting
        // These have different field names (capitalized, with units) than raw fields
        final formattedFields = stats.getMessageFields();
        
        for (final field in formattedFields.entries) {
          final fieldKey = '$messageName.${field.key}';
          
          // Skip if we've reached field limit (prevent unbounded growth)
          if (_dataBuffers.length >= maxFieldCount && !_dataBuffers.containsKey(fieldKey)) {
            continue;
          }
          
          final value = _parseNumericValue(field.value);
          
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

  /// Parse numeric values from formatted strings (for backward compatibility)
  double? _parseNumericValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    } else if (value is String) {
      // First try direct parse
      final result = double.tryParse(value);
      if (result != null) return result;
      
      // Try removing units and symbols
      final cleaned = value.replaceAll(RegExp(r'[^\d\.\-eE\+]'), '');
      return double.tryParse(cleaned);
    }
    return null;
  }

  /// Extract raw numeric fields directly from MAVLink messages
  Map<String, double?> _extractRawMessageFields(String messageName, MavlinkMessage message) {
    final fields = <String, double?>{};
    
    if (message is Heartbeat) {
      fields['type'] = message.type.toDouble();
      fields['autopilot'] = message.autopilot.toDouble();
      fields['baseMode'] = message.baseMode.toDouble();
      fields['customMode'] = message.customMode.toDouble();
      fields['systemStatus'] = message.systemStatus.toDouble();
      fields['mavlinkVersion'] = message.mavlinkVersion.toDouble();
    } else if (message is SysStatus) {
      fields['voltageBattery'] = message.voltageBattery.toDouble();
      fields['currentBattery'] = message.currentBattery.toDouble();
      fields['batteryRemaining'] = message.batteryRemaining.toDouble();
      fields['load'] = message.load.toDouble();
      fields['dropRateComm'] = message.dropRateComm.toDouble();
      fields['errorsComm'] = message.errorsComm.toDouble();
    } else if (message is Attitude) {
      fields['roll'] = message.roll;
      fields['pitch'] = message.pitch;
      fields['yaw'] = message.yaw;
      fields['rollspeed'] = message.rollspeed;
      fields['pitchspeed'] = message.pitchspeed;
      fields['yawspeed'] = message.yawspeed;
      fields['timeBootMs'] = message.timeBootMs.toDouble();
    } else if (message is GlobalPositionInt) {
      fields['lat'] = message.lat.toDouble();
      fields['lon'] = message.lon.toDouble();
      fields['alt'] = message.alt.toDouble();
      fields['relativeAlt'] = message.relativeAlt.toDouble();
      fields['vx'] = message.vx.toDouble();
      fields['vy'] = message.vy.toDouble();
      fields['vz'] = message.vz.toDouble();
      fields['hdg'] = message.hdg.toDouble();
      fields['timeBootMs'] = message.timeBootMs.toDouble();
    } else if (message is VfrHud) {
      fields['airspeed'] = message.airspeed;
      fields['groundspeed'] = message.groundspeed;
      fields['heading'] = message.heading.toDouble();
      fields['throttle'] = message.throttle.toDouble();
      fields['alt'] = message.alt;
      fields['climb'] = message.climb;
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