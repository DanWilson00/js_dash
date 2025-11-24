import 'timeseries_point.dart';

class CircularBuffer {
  final int capacity;
  final List<TimeSeriesPoint> _points = [];

  CircularBuffer(this.capacity);

  void add(TimeSeriesPoint point) {
    if (_points.length >= capacity) {
      _points.removeAt(0);
    }
    _points.add(point);
  }

  void removeOldData(DateTime cutoff) {
    _points.removeWhere((p) => p.timestamp.isBefore(cutoff));
  }

  List<TimeSeriesPoint> get points => List.unmodifiable(_points);

  int get length => _points.length;
}
