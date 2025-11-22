import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'json_converters.dart';

part 'plot_configuration.g.dart';

class TimeSeriesPoint {
  final DateTime timestamp;
  final double value;

  TimeSeriesPoint(this.timestamp, this.value);
}

class CircularBuffer {
  final Queue<TimeSeriesPoint> _buffer = Queue<TimeSeriesPoint>();
  final int maxSize;

  CircularBuffer(this.maxSize);

  void add(TimeSeriesPoint point) {
    if (_buffer.length >= maxSize) {
      _buffer.removeFirst();
    }
    _buffer.addLast(point);
  }

  List<TimeSeriesPoint> get points => _buffer.toList();

  void clear() {
    _buffer.clear();
  }

  void removeOldData(DateTime cutoff) {
    while (_buffer.isNotEmpty && _buffer.first.timestamp.isBefore(cutoff)) {
      _buffer.removeFirst();
    }
  }

  bool get isEmpty => _buffer.isEmpty;
  int get length => _buffer.length;
}

enum ScalingMode {
  unified, // All signals share same Y-axis bounds
  independent, // Each signal normalized to 0-100%
  autoScale, // Calculate bounds from all signals combined
}

@JsonSerializable()
class PlotSignalConfiguration {
  final String id;
  final String messageType;
  final String fieldName;
  final String? units;
  @ColorConverter()
  final Color color;
  final bool visible;
  final String? displayName;
  final double lineWidth;
  final bool showDots;

  PlotSignalConfiguration({
    required this.id,
    required this.messageType,
    required this.fieldName,
    this.units,
    required this.color,
    this.visible = true,
    this.displayName,
    this.lineWidth = 2.0,
    this.showDots = false,
  });

  factory PlotSignalConfiguration.fromJson(Map<String, dynamic> json) =>
      _$PlotSignalConfigurationFromJson(json);
  Map<String, dynamic> toJson() => _$PlotSignalConfigurationToJson(this);

  String get effectiveDisplayName => displayName ?? '$messageType.$fieldName';

  String get fieldKey => '$messageType.$fieldName';

  PlotSignalConfiguration copyWith({
    String? id,
    String? messageType,
    String? fieldName,
    String? units,
    Color? color,
    bool? visible,
    String? displayName,
    double? lineWidth,
    bool? showDots,
  }) {
    return PlotSignalConfiguration(
      id: id ?? this.id,
      messageType: messageType ?? this.messageType,
      fieldName: fieldName ?? this.fieldName,
      units: units ?? this.units,
      color: color ?? this.color,
      visible: visible ?? this.visible,
      displayName: displayName ?? this.displayName,
      lineWidth: lineWidth ?? this.lineWidth,
      showDots: showDots ?? this.showDots,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlotSignalConfiguration &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

@JsonSerializable()
class PlotAxisConfiguration {
  final List<PlotSignalConfiguration> signals;
  final double? minY;
  final double? maxY;
  final ScalingMode scalingMode;

  PlotAxisConfiguration({
    List<PlotSignalConfiguration>? signals,
    this.minY,
    this.maxY,
    this.scalingMode = ScalingMode.autoScale,
  }) : signals = signals ?? [];

  factory PlotAxisConfiguration.fromJson(Map<String, dynamic> json) =>
      _$PlotAxisConfigurationFromJson(json);
  Map<String, dynamic> toJson() => _$PlotAxisConfigurationToJson(this);

  bool get hasData => signals.isNotEmpty;
  bool get hasVisibleSignals => signals.any((s) => s.visible);

  List<PlotSignalConfiguration> get visibleSignals =>
      signals.where((s) => s.visible).toList();

  String get displayName {
    if (!hasData) return 'No Data';
    if (signals.length == 1) return signals.first.effectiveDisplayName;
    return '${signals.length} signals';
  }

  // Legacy compatibility - returns first signal's data or null
  String? get messageType =>
      signals.isNotEmpty ? signals.first.messageType : null;
  String? get fieldName => signals.isNotEmpty ? signals.first.fieldName : null;
  String? get units => signals.isNotEmpty ? signals.first.units : null;
  bool get autoScale => scalingMode == ScalingMode.autoScale;

  PlotAxisConfiguration copyWith({
    List<PlotSignalConfiguration>? signals,
    double? minY,
    double? maxY,
    ScalingMode? scalingMode,
    // Legacy compatibility parameters
    String? messageType,
    String? fieldName,
    String? units,
    bool? autoScale,
  }) {
    List<PlotSignalConfiguration> newSignals = signals ?? this.signals;

    // Handle legacy single-signal assignment
    if (messageType != null && fieldName != null) {
      final color = SignalColorPalette.getNextColor(newSignals.length);
      final signal = PlotSignalConfiguration(
        id: '${messageType}_${fieldName}_${DateTime.now().millisecondsSinceEpoch}',
        messageType: messageType,
        fieldName: fieldName,
        units: units,
        color: color,
      );
      newSignals = [signal];
    }

    ScalingMode newScalingMode = scalingMode ?? this.scalingMode;
    if (autoScale != null) {
      newScalingMode = autoScale ? ScalingMode.autoScale : ScalingMode.unified;
    }

    return PlotAxisConfiguration(
      signals: newSignals,
      minY: minY ?? this.minY,
      maxY: maxY ?? this.maxY,
      scalingMode: newScalingMode,
    );
  }

  PlotAxisConfiguration addSignal(PlotSignalConfiguration signal) {
    return copyWith(signals: [...signals, signal]);
  }

  PlotAxisConfiguration removeSignal(String signalId) {
    return copyWith(signals: signals.where((s) => s.id != signalId).toList());
  }

  PlotAxisConfiguration updateSignal(PlotSignalConfiguration updatedSignal) {
    return copyWith(
      signals: signals
          .map((s) => s.id == updatedSignal.id ? updatedSignal : s)
          .toList(),
    );
  }

  PlotAxisConfiguration clear() {
    return PlotAxisConfiguration(
      scalingMode: scalingMode,
      minY: minY,
      maxY: maxY,
    );
  }
}

@JsonSerializable()
class PlotLayoutData {
  final double x;
  final double y;
  final double width;
  final double height;

  const PlotLayoutData({
    this.x = 0.0,
    this.y = 0.0,
    this.width = 0.5,
    this.height = 0.5,
  });

  factory PlotLayoutData.fromJson(Map<String, dynamic> json) =>
      _$PlotLayoutDataFromJson(json);
  Map<String, dynamic> toJson() => _$PlotLayoutDataToJson(this);

  PlotLayoutData copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return PlotLayoutData(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

@JsonSerializable()
class PlotConfiguration {
  final String id;
  final String title;
  final PlotAxisConfiguration yAxis;
  @DurationConverter()
  final Duration timeWindow;
  final PlotLayoutData layoutData;

  PlotConfiguration({
    required this.id,
    this.title = 'Time Series Plot',
    PlotAxisConfiguration? yAxis,
    this.timeWindow = const Duration(minutes: 5),
    PlotLayoutData? layoutData,
  }) : yAxis = yAxis ?? PlotAxisConfiguration(),
       layoutData = layoutData ?? const PlotLayoutData();

  factory PlotConfiguration.fromJson(Map<String, dynamic> json) =>
      _$PlotConfigurationFromJson(json);
  Map<String, dynamic> toJson() => _$PlotConfigurationToJson(this);

  PlotConfiguration copyWith({
    String? id,
    String? title,
    PlotAxisConfiguration? yAxis,
    Duration? timeWindow,
    PlotLayoutData? layoutData,
  }) {
    return PlotConfiguration(
      id: id ?? this.id,
      title: title ?? this.title,
      yAxis: yAxis ?? this.yAxis,
      timeWindow: timeWindow ?? this.timeWindow,
      layoutData: layoutData ?? this.layoutData,
    );
  }

  // Convenience methods for signal management
  PlotConfiguration addSignal(PlotSignalConfiguration signal) {
    return copyWith(yAxis: yAxis.addSignal(signal));
  }

  PlotConfiguration removeSignal(String signalId) {
    return copyWith(yAxis: yAxis.removeSignal(signalId));
  }

  PlotConfiguration updateSignal(PlotSignalConfiguration updatedSignal) {
    return copyWith(yAxis: yAxis.updateSignal(updatedSignal));
  }
}

class TimeWindowOption {
  final Duration duration;
  final String label;

  const TimeWindowOption(this.duration, this.label);

  static const List<TimeWindowOption> availableWindows = [
    TimeWindowOption(Duration(seconds: 5), '5s'),
    TimeWindowOption(Duration(seconds: 10), '10s'),
    TimeWindowOption(Duration(seconds: 30), '30s'),
    TimeWindowOption(Duration(minutes: 1), '1m'),
    TimeWindowOption(Duration(minutes: 2), '2m'),
    TimeWindowOption(Duration(minutes: 5), '5m'),
  ];

  static TimeWindowOption getDefault() => availableWindows[1]; // 10s

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeWindowOption &&
          runtimeType == other.runtimeType &&
          duration == other.duration;

  @override
  int get hashCode => duration.hashCode;
}

class SignalColorPalette {
  static const List<Color> _colors = [
    Color(0xFF2196F3), // Blue
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF4CAF50), // Green
    Color(0xFF9C27B0), // Purple
    Color(0xFFFF9800), // Orange
    Color(0xFF00BCD4), // Cyan
    Color(0xFFE91E63), // Pink
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
    Color(0xFFFFC107), // Amber
  ];

  static Color getNextColor(int index) {
    return _colors[index % _colors.length];
  }

  static Color getNextAvailableColor(List<Color> usedColors) {
    // Try to find a color that's not in use
    for (final color in _colors) {
      if (!usedColors.contains(color)) {
        return color;
      }
    }
    // If all colors are used, fallback to the least used color
    // by counting occurrences
    final colorCounts = <Color, int>{};
    for (final color in _colors) {
      colorCounts[color] = 0;
    }
    for (final usedColor in usedColors) {
      if (colorCounts.containsKey(usedColor)) {
        colorCounts[usedColor] = colorCounts[usedColor]! + 1;
      }
    }
    // Find the color with minimum usage
    Color leastUsedColor = _colors.first;
    int minCount = colorCounts[_colors.first] ?? 0;
    for (final entry in colorCounts.entries) {
      if (entry.value < minCount) {
        minCount = entry.value;
        leastUsedColor = entry.key;
      }
    }
    return leastUsedColor;
  }

  static Color getColorForSignal(String signalId) {
    // Generate consistent color based on signal ID hash
    final hash = signalId.hashCode.abs();
    return _colors[hash % _colors.length];
  }

  static List<Color> get availableColors => List.unmodifiable(_colors);
}
