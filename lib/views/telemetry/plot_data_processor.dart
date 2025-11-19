import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import '../../models/plot_configuration.dart';
import '../../models/app_settings.dart';
import '../../services/timeseries_data_manager.dart';

// Data transfer objects
class ComputeInput {
  final List<PlotSignalConfiguration> visibleSignals;
  final Map<String, List<TimeSeriesPoint>> allData;
  final TimeWindow timeWindow;
  final ScalingMode scalingMode;
  final PerformanceSettings performance;
  final DateTime absoluteEpoch;
  final Map<String, DateTime> lastDataTimestamps;

  ComputeInput({
    required this.visibleSignals,
    required this.allData,
    required this.timeWindow,
    required this.scalingMode,
    required this.performance,
    required this.absoluteEpoch,
    required this.lastDataTimestamps,
  });
}

class TimeWindow {
  final DateTime startTime;
  final DateTime cutoff;

  TimeWindow({required this.startTime, required this.cutoff});
}

class DataProcessingResult {
  final Map<String, List<FlSpot>> signalSpots;
  final Map<String, Map<double, double>> originalValues;
  final List<double> allValues;
  final bool hasNewData;
  final Map<String, DateTime> latestTimestamps;

  DataProcessingResult({
    required this.signalSpots,
    required this.originalValues,
    required this.allValues,
    required this.hasNewData,
    required this.latestTimestamps,
  });
}

class SpotsAndValues {
  final List<FlSpot> spots;
  final Map<double, double> originalValues;

  SpotsAndValues({required this.spots, required this.originalValues});
}

class YAxisBounds {
  final double minY;
  final double maxY;

  YAxisBounds({required this.minY, required this.maxY});
}

// Isolate processing function
DataProcessingResult processDataInIsolate(ComputeInput input) {
  final signalSpots = <String, List<FlSpot>>{};
  final originalValues = <String, Map<double, double>>{};
  final allValues = <double>[];
  bool hasNewData = false;
  final latestTimestamps = <String, DateTime>{};

  for (final signal in input.visibleSignals) {
    final fieldKey = signal.fieldKey;
    final data = input.allData[fieldKey] ?? [];

    // Check for new data
    if (data.isNotEmpty) {
      final latestTimestamp = data.last.timestamp;
      final lastKnownTimestamp = input.lastDataTimestamps[fieldKey];

      if (lastKnownTimestamp == null ||
          latestTimestamp.isAfter(lastKnownTimestamp)) {
        hasNewData = true;
        latestTimestamps[fieldKey] = latestTimestamp;
      }
    }

    final filteredData = filterDataByTime(data, input.timeWindow.cutoff);
    final spotsAndValues = convertToFlSpotsWithValues(
      filteredData,
      input.timeWindow.startTime,
      input.scalingMode,
      input.performance,
      input.absoluteEpoch,
    );

    signalSpots[fieldKey] = spotsAndValues.spots;
    originalValues[fieldKey] = spotsAndValues.originalValues;

    if (input.scalingMode != ScalingMode.independent) {
      allValues.addAll(spotsAndValues.spots.map((s) => s.y));
    } else {
      allValues.addAll(spotsAndValues.originalValues.values);
    }
  }

  return DataProcessingResult(
    signalSpots: signalSpots,
    originalValues: originalValues,
    allValues: allValues,
    hasNewData: hasNewData,
    latestTimestamps: latestTimestamps,
  );
}

// Static helper functions
List<TimeSeriesPoint> filterDataByTime(
  List<TimeSeriesPoint> data,
  DateTime cutoff,
) {
  return data.where((point) => point.timestamp.isAfter(cutoff)).toList();
}

SpotsAndValues convertToFlSpotsWithValues(
  List<TimeSeriesPoint> filteredData,
  DateTime startTime,
  ScalingMode scalingMode,
  PerformanceSettings performance,
  DateTime absoluteEpoch,
) {
  if (filteredData.isEmpty) {
    return SpotsAndValues(spots: [], originalValues: {});
  }

  final decimatedData = decimateData(filteredData, performance);
  final originalValues = <double, double>{};

  List<FlSpot> spots;
  if (scalingMode == ScalingMode.independent) {
    spots = createNormalizedFlSpotsWithValues(
      decimatedData,
      startTime,
      originalValues,
      absoluteEpoch,
    );
  } else {
    spots = createRawFlSpotsWithValues(
      decimatedData,
      startTime,
      originalValues,
      absoluteEpoch,
    );
  }

  return SpotsAndValues(spots: spots, originalValues: originalValues);
}

List<TimeSeriesPoint> decimateData(
  List<TimeSeriesPoint> data,
  PerformanceSettings performance,
) {
  if (!performance.enablePointDecimation) {
    return data;
  }

  final maxPoints = performance.decimationThreshold;

  if (data.length <= maxPoints) {
    return data;
  }

  return largestTriangleThreeBuckets(data, maxPoints);
}

List<TimeSeriesPoint> largestTriangleThreeBuckets(
  List<TimeSeriesPoint> data,
  int targetPoints,
) {
  if (data.length <= targetPoints) return data;

  final result = <TimeSeriesPoint>[];
  final bucketSize = (data.length - 2) / (targetPoints - 2);

  result.add(data.first);

  for (int i = 1; i < targetPoints - 1; i++) {
    final bucketStart = ((i - 1) * bucketSize + 1).floor();
    final bucketEnd = (i * bucketSize + 1).floor();

    double nextBucketAvgX = 0;
    double nextBucketAvgY = 0;
    int nextBucketCount = 0;

    final nextBucketStart = bucketEnd;
    final nextBucketEnd = ((i + 1) * bucketSize + 1).floor().clamp(
      0,
      data.length - 1,
    );

    for (int j = nextBucketStart; j < nextBucketEnd && j < data.length; j++) {
      final point = data[j];
      nextBucketAvgX += point.timestamp.millisecondsSinceEpoch.toDouble();
      nextBucketAvgY += point.value;
      nextBucketCount++;
    }

    if (nextBucketCount > 0) {
      nextBucketAvgX /= nextBucketCount;
      nextBucketAvgY /= nextBucketCount;
    } else {
      // If no points in next bucket (e.g. last bucket), use the last data point
      final lastPoint = data.last;
      nextBucketAvgX = lastPoint.timestamp.millisecondsSinceEpoch.toDouble();
      nextBucketAvgY = lastPoint.value;
    }

    double maxArea = -1.0; // Start with -1 to ensure we pick at least one point
    TimeSeriesPoint? selectedPoint;

    for (int j = bucketStart; j < bucketEnd && j < data.length; j++) {
      final point = data[j];
      final prevPoint = result.last;

      final area =
          (prevPoint.timestamp.millisecondsSinceEpoch *
                      (point.value - nextBucketAvgY) +
                  point.timestamp.millisecondsSinceEpoch *
                      (nextBucketAvgY - prevPoint.value) +
                  nextBucketAvgX * (prevPoint.value - point.value))
              .abs();

      if (area > maxArea) {
        maxArea = area;
        selectedPoint = point;
      }
    }

    // Fallback if no point selected (shouldn't happen with maxArea = -1)
    selectedPoint ??= data[bucketStart];

    if (selectedPoint != null) {
      result.add(selectedPoint);
    }
  }

  result.add(data.last);

  return result;
}

List<FlSpot> createNormalizedFlSpotsWithValues(
  List<TimeSeriesPoint> data,
  DateTime startTime,
  Map<double, double> originalValues,
  DateTime absoluteEpoch,
) {
  if (data.isEmpty) return [];

  final values = data.map((p) => p.value).toList();
  final minVal = values.reduce((a, b) => a < b ? a : b);
  final maxVal = values.reduce((a, b) => a > b ? a : b);
  final range = maxVal - minVal;

  return data.map((point) {
    final x = point.timestamp
        .difference(absoluteEpoch)
        .inMilliseconds
        .toDouble();
    final normalizedY = range > 0
        ? ((point.value - minVal) / range) * 100.0
        : 50.0;
    originalValues[x] = point.value;
    return FlSpot(x, normalizedY);
  }).toList();
}

List<FlSpot> createRawFlSpotsWithValues(
  List<TimeSeriesPoint> data,
  DateTime startTime,
  Map<double, double> originalValues,
  DateTime absoluteEpoch,
) {
  return data.map((point) {
    final x = point.timestamp
        .difference(absoluteEpoch)
        .inMilliseconds
        .toDouble();
    originalValues[x] = point.value;
    return FlSpot(x, point.value);
  }).toList();
}
