import 'dart:collection';

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

  bool get isEmpty => _buffer.isEmpty;
  int get length => _buffer.length;
}

class PlotAxisConfiguration {
  final String? messageType;
  final String? fieldName;
  final String? units;
  final double? minY;
  final double? maxY;
  final bool autoScale;

  PlotAxisConfiguration({
    this.messageType,
    this.fieldName,
    this.units,
    this.minY,
    this.maxY,
    this.autoScale = true,
  });

  bool get hasData => messageType != null && fieldName != null;

  String get displayName => 
    hasData ? '$messageType.$fieldName' : 'No Data';

  PlotAxisConfiguration copyWith({
    String? messageType,
    String? fieldName,
    String? units,
    double? minY,
    double? maxY,
    bool? autoScale,
  }) {
    return PlotAxisConfiguration(
      messageType: messageType ?? this.messageType,
      fieldName: fieldName ?? this.fieldName,
      units: units ?? this.units,
      minY: minY ?? this.minY,
      maxY: maxY ?? this.maxY,
      autoScale: autoScale ?? this.autoScale,
    );
  }

  PlotAxisConfiguration clear() {
    return PlotAxisConfiguration(
      autoScale: autoScale,
    );
  }
}

class PlotConfiguration {
  final String id;
  final String title;
  final PlotAxisConfiguration yAxis;
  final Duration timeWindow;

  PlotConfiguration({
    required this.id,
    this.title = 'Time Series Plot',
    PlotAxisConfiguration? yAxis,
    this.timeWindow = const Duration(minutes: 5),
  }) : yAxis = yAxis ?? PlotAxisConfiguration();

  PlotConfiguration copyWith({
    String? id,
    String? title,
    PlotAxisConfiguration? yAxis,
    Duration? timeWindow,
  }) {
    return PlotConfiguration(
      id: id ?? this.id,
      title: title ?? this.title,
      yAxis: yAxis ?? this.yAxis,
      timeWindow: timeWindow ?? this.timeWindow,
    );
  }
}

enum PlotLayoutType {
  single,   // 1x1
  horizontal, // 1x2
  vertical,   // 2x1
  grid2x2,    // 2x2
  grid3x2,    // 3x2
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

class PlotLayout {
  final PlotLayoutType type;
  final int rows;
  final int columns;

  const PlotLayout._(this.type, this.rows, this.columns);

  static const PlotLayout single = PlotLayout._(PlotLayoutType.single, 1, 1);
  static const PlotLayout horizontal = PlotLayout._(PlotLayoutType.horizontal, 1, 2);
  static const PlotLayout vertical = PlotLayout._(PlotLayoutType.vertical, 2, 1);
  static const PlotLayout grid2x2 = PlotLayout._(PlotLayoutType.grid2x2, 2, 2);
  static const PlotLayout grid3x2 = PlotLayout._(PlotLayoutType.grid3x2, 2, 3);

  int get maxPlots => rows * columns;

  static List<PlotLayout> getAvailableLayouts(int plotCount) {
    final layouts = <PlotLayout>[];
    
    if (plotCount >= 1) layouts.add(single);
    if (plotCount >= 2) {
      layouts.add(horizontal);
      layouts.add(vertical);
    }
    if (plotCount >= 3) layouts.add(grid2x2);
    if (plotCount >= 5) layouts.add(grid3x2);
    
    return layouts;
  }

  static PlotLayout getDefaultLayout(int plotCount) {
    switch (plotCount) {
      case 1: return single;
      case 2: return horizontal;
      case 3:
      case 4: return grid2x2;
      case 5:
      case 6: return grid3x2;
      default: return single;
    }
  }

  @override
  String toString() {
    switch (type) {
      case PlotLayoutType.single: return '1×1';
      case PlotLayoutType.horizontal: return '1×2';
      case PlotLayoutType.vertical: return '2×1';
      case PlotLayoutType.grid2x2: return '2×2';
      case PlotLayoutType.grid3x2: return '2×3';
    }
  }
}