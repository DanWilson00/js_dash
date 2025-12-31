import 'dart:async';
import 'dart:math' as math;

import '../mavlink/mavlink.dart';

/// Statistics for a single message type.
class GenericMessageStats {
  int count = 0;
  DateTime firstReceived = DateTime.now();
  DateTime lastReceived = DateTime.now();
  MavlinkMessage? lastMessage;
  double frequency = 0.0;

  // For responsive frequency calculation
  final List<DateTime> _recentTimestamps = [];

  void updateMessage(MavlinkMessage message) {
    count++;
    lastReceived = DateTime.now();
    lastMessage = message;

    // Track recent timestamps for frequency calculation
    // NOTE: Cleanup and frequency calculation deferred to updateFrequency()
    // which is called by the tracker's timer (100ms) instead of per-message
    // This avoids O(n) removeWhere() on every incoming message (60+/sec)
    _recentTimestamps.add(lastReceived);
  }

  /// Update frequency calculation and cleanup old timestamps.
  /// Called by GenericMessageTracker's timer (every 100ms) instead of per-message.
  void updateFrequency() {
    // Keep only timestamps from the last 5 seconds
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(seconds: 5));
    _recentTimestamps.removeWhere((timestamp) => timestamp.isBefore(cutoff));

    // Calculate frequency based on recent activity
    if (_recentTimestamps.length > 1) {
      final timeSpan = _recentTimestamps.last.difference(
        _recentTimestamps.first,
      );
      if (timeSpan.inMilliseconds > 0) {
        frequency =
            (_recentTimestamps.length - 1) / (timeSpan.inMilliseconds / 1000.0);
      }
    } else if (_recentTimestamps.length == 1) {
      frequency = 0.0;
    }
  }

  /// Get formatted field values for display.
  ///
  /// Uses metadata to format values with units and enum resolution.
  Map<String, String> getFormattedFields(MavlinkMetadataRegistry registry) {
    if (lastMessage == null) return {};

    final formatted = <String, String>{};
    final metadata = lastMessage!.metadata;

    for (final field in metadata.fields) {
      final value = lastMessage!.values[field.name];
      if (value == null) continue;

      formatted[field.name] = _formatFieldValue(value, field, registry);
    }

    return formatted;
  }

  String _formatFieldValue(
    dynamic value,
    MavlinkFieldMetadata field,
    MavlinkMetadataRegistry registry,
  ) {
    // Handle enum resolution
    if (field.enumType != null && value is int) {
      final enumName = registry.resolveEnumValue(field.enumType!, value);
      if (enumName != null) {
        return enumName;
      }
    }

    // Handle unit formatting
    String formatted;
    if (value is double) {
      formatted = value.toStringAsFixed(3);
    } else if (value is List) {
      formatted = value.toString();
    } else {
      formatted = value.toString();
    }

    // Apply unit conversions for common cases
    if (field.units != null && field.units!.isNotEmpty) {
      // Strip brackets from units (JSON has "[degE7]", we check "degE7")
      final units = field.units!.replaceAll(RegExp(r'[\[\]]'), '');

      // Radians to degrees for display
      if (units == 'rad' && value is num) {
        final degrees = value * 180 / math.pi;
        formatted = '${degrees.toStringAsFixed(2)}°';
      } else if (units == 'rad/s' && value is num) {
        formatted = '${value.toStringAsFixed(3)} rad/s';
      } else if (units == 'degE7' && value is int) {
        formatted = '${(value / 1e7).toStringAsFixed(7)}°';
      } else if (units == 'mm' && value is int) {
        formatted = '${(value / 1000.0).toStringAsFixed(3)} m';
      } else if (units == 'cm' && value is int) {
        formatted = '${(value / 100.0).toStringAsFixed(2)} m';
      } else if (units == 'cm/s' && value is int) {
        formatted = '${(value / 100.0).toStringAsFixed(2)} m/s';
      } else if (units == 'cdeg' && value is int) {
        formatted = '${(value / 100.0).toStringAsFixed(1)}°';
      } else if (units == 'mV' && value is int) {
        formatted = '${(value / 1000.0).toStringAsFixed(3)} V';
      } else if (units == 'cA' && value is int) {
        formatted = '${(value / 100.0).toStringAsFixed(2)} A';
      } else if (units == 'd%' && value is int) {
        formatted = '${(value / 10.0).toStringAsFixed(1)}%';
      } else if (units == 'c%' && value is int) {
        formatted = '${(value / 100.0).toStringAsFixed(2)}%';
      } else if (units == 'ms' && value is int) {
        formatted = '$value ms';
      } else {
        formatted = '$formatted $units';
      }
    }

    return formatted;
  }
}

/// Generic message tracker that works with metadata-driven messages.
class GenericMessageTracker {
  static const Duration _statsUpdateInterval = Duration(milliseconds: 100);

  final MavlinkMetadataRegistry _registry;
  final Map<String, GenericMessageStats> _messageStats = {};
  final StreamController<Map<String, GenericMessageStats>> _statsController =
      StreamController<Map<String, GenericMessageStats>>.broadcast();

  Timer? _updateTimer;
  bool _isTracking = false;

  GenericMessageTracker(this._registry);

  /// The metadata registry for enum/unit resolution.
  MavlinkMetadataRegistry get registry => _registry;

  Stream<Map<String, GenericMessageStats>> get statsStream =>
      _statsController.stream;

  Map<String, GenericMessageStats> get currentStats =>
      Map.unmodifiable(_messageStats);

  int get totalMessages =>
      _messageStats.values.fold(0, (sum, stats) => sum + stats.count);

  void startTracking() {
    if (_isTracking) return;
    _isTracking = true;

    _updateTimer = Timer.periodic(_statsUpdateInterval, (_) {
      if (!_statsController.isClosed) {
        _updateFrequencies();
        _statsController.add(Map.from(_messageStats));
      }
    });
  }

  void stopTracking() {
    _isTracking = false;
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  void trackMessage(MavlinkMessage message) {
    if (!_isTracking) return;

    _messageStats.putIfAbsent(message.name, () => GenericMessageStats());
    _messageStats[message.name]!.updateMessage(message);
  }

  void _updateFrequencies() {
    final now = DateTime.now();
    const staleThreshold = Duration(seconds: 10);

    // Remove messages not received for 10+ seconds
    _messageStats.removeWhere((name, stats) =>
      now.difference(stats.lastReceived) > staleThreshold
    );

    for (final stats in _messageStats.values) {
      // Update frequency and cleanup timestamps (deferred from per-message)
      stats.updateFrequency();

      final timeSinceLastMessage = now.difference(stats.lastReceived);

      // Decay frequency if no messages recently
      if (timeSinceLastMessage.inMilliseconds > 2000) {
        final decayFactor =
            1.0 - (timeSinceLastMessage.inMilliseconds - 2000) / 3000.0;
        stats.frequency = (stats.frequency * decayFactor.clamp(0.0, 1.0));

        if (stats.frequency < 0.01) {
          stats.frequency = 0.0;
        }
      }
    }
  }

  void clearStats() {
    _messageStats.clear();
    if (!_statsController.isClosed) {
      _statsController.add({});
    }
  }

  void dispose() {
    stopTracking();
    if (!_statsController.isClosed) {
      _statsController.close();
    }
  }
}
