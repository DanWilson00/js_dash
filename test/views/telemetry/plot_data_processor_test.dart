import 'package:flutter_test/flutter_test.dart';

import 'package:js_dash/views/telemetry/plot_data_processor.dart';
import 'package:js_dash/models/app_settings.dart';
import 'package:js_dash/models/plot_configuration.dart';
import 'package:js_dash/core/timeseries_point.dart';

void main() {
  group('PlotDataProcessor', () {
    test('filterDataByTime returns correct data points', () {
      final now = DateTime.now();
      final data = [
        TimeSeriesPoint(now.subtract(const Duration(minutes: 10)), 1.0),
        TimeSeriesPoint(
          now.subtract(const Duration(minutes: 5)),
          2.0,
        ), // Should be included
        TimeSeriesPoint(
          now.subtract(const Duration(minutes: 1)),
          3.0,
        ), // Should be included
      ];
      final cutoff = now.subtract(const Duration(minutes: 6));

      final filtered = filterDataByTime(data, cutoff);

      expect(filtered.length, 2);
      expect(filtered[0].value, 2.0);
      expect(filtered[1].value, 3.0);
    });

    test('decimateData returns original data if below threshold', () {
      final data = List.generate(
        10,
        (i) => TimeSeriesPoint(
          DateTime.now().add(Duration(seconds: i)),
          i.toDouble(),
        ),
      );
      final performance = PerformanceSettings.defaults().copyWith(
        enablePointDecimation: true,
        decimationThreshold: 20,
      );

      final decimated = decimateData(data, performance);

      expect(decimated.length, 10);
    });

    test('decimateData reduces data points when above threshold', () {
      final data = List.generate(
        100,
        (i) => TimeSeriesPoint(
          DateTime.now().add(Duration(seconds: i)),
          i.toDouble(),
        ),
      );
      final performance = PerformanceSettings.defaults().copyWith(
        enablePointDecimation: true,
        decimationThreshold: 10,
      );

      final decimated = decimateData(data, performance);

      expect(decimated.length, 10);
      // First and last points should always be preserved
      expect(decimated.first.value, 0.0);
      expect(decimated.last.value, 99.0);
    });

    test('convertToFlSpotsWithValues normalizes time correctly', () {
      final startTime = DateTime(2023, 1, 1, 12, 0, 0);
      final absoluteEpoch = DateTime(2020, 1, 1);
      final data = [
        TimeSeriesPoint(startTime, 10.0),
        TimeSeriesPoint(startTime.add(const Duration(seconds: 1)), 20.0),
      ];
      final performance = PerformanceSettings.defaults();

      final result = convertToFlSpotsWithValues(
        data,
        startTime,
        ScalingMode.unified,
        performance,
        absoluteEpoch,
      );

      expect(result.spots.length, 2);
      // X is milliseconds since absoluteEpoch
      final expectedX0 = startTime
          .difference(absoluteEpoch)
          .inMilliseconds
          .toDouble();
      final expectedX1 = startTime
          .add(const Duration(seconds: 1))
          .difference(absoluteEpoch)
          .inMilliseconds
          .toDouble();

      expect(result.spots[0].x, expectedX0);
      expect(
        result.spots[0].y,
        10.0,
      ); // Unified scaling keeps original Y (if not normalized)
      expect(result.spots[1].x, expectedX1);
      expect(result.spots[1].y, 20.0);
    });

    test('largestTriangleThreeBuckets preserves shape', () {
      // Simple triangle shape: 0 -> 10 -> 0
      final data = [
        TimeSeriesPoint(DateTime(2023, 1, 1, 10, 0), 0),
        TimeSeriesPoint(DateTime(2023, 1, 1, 10, 1), 2),
        TimeSeriesPoint(DateTime(2023, 1, 1, 10, 2), 4),
        TimeSeriesPoint(DateTime(2023, 1, 1, 10, 3), 6),
        TimeSeriesPoint(DateTime(2023, 1, 1, 10, 4), 8),
        TimeSeriesPoint(DateTime(2023, 1, 1, 10, 5), 10), // Peak
        TimeSeriesPoint(DateTime(2023, 1, 1, 10, 6), 8),
        TimeSeriesPoint(DateTime(2023, 1, 1, 10, 7), 6),
        TimeSeriesPoint(DateTime(2023, 1, 1, 10, 8), 4),
        TimeSeriesPoint(DateTime(2023, 1, 1, 10, 9), 2),
        TimeSeriesPoint(DateTime(2023, 1, 1, 10, 10), 0),
      ];

      // Decimate to 3 points (Start, Peak, End ideally)
      final decimated = largestTriangleThreeBuckets(data, 3);

      expect(decimated.length, 3);
      expect(decimated[0].value, 0);
      expect(decimated[2].value, 0);
      // The middle point should be the peak or close to it
      expect(decimated[1].value, 10);
    });
  });
}
