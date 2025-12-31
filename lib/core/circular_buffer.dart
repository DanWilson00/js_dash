import 'dart:collection';
import 'timeseries_point.dart';

class CircularBuffer {
  final int capacity;
  final ListQueue<TimeSeriesPoint> _points = ListQueue<TimeSeriesPoint>();

  CircularBuffer(this.capacity);

  void add(TimeSeriesPoint point) {
    if (_points.length >= capacity) {
      _points.removeFirst();
    }
    _points.addLast(point);
  }

  void removeOldData(DateTime cutoff) {
    while (_points.isNotEmpty && _points.first.timestamp.isBefore(cutoff)) {
      _points.removeFirst();
    }
  }

  // Returns an unmodifiable list view for consumers who need index access
  List<TimeSeriesPoint> get points => _points.toList(growable: false);

  int get length => _points.length;

  bool get isEmpty => _points.isEmpty;

  void clear() {
    _points.clear();
  }
}
