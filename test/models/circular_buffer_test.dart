import 'package:flutter_test/flutter_test.dart';
import 'package:js_dash/models/plot_configuration.dart';

void main() {
  group('CircularBuffer', () {
    late CircularBuffer buffer;
    const int bufferSize = 5;

    setUp(() {
      buffer = CircularBuffer(bufferSize);
    });

    test('initializes empty', () {
      expect(buffer.isEmpty, isTrue);
      expect(buffer.length, equals(0));
      expect(buffer.points, isEmpty);
    });

    test('adds points until capacity', () {
      final now = DateTime.now();
      
      for (int i = 0; i < bufferSize; i++) {
        buffer.add(TimeSeriesPoint(now.add(Duration(seconds: i)), i.toDouble()));
        expect(buffer.length, equals(i + 1));
      }

      expect(buffer.length, equals(bufferSize));
      expect(buffer.points.length, equals(bufferSize));
      
      // Verify points are in order
      final points = buffer.points;
      for (int i = 0; i < bufferSize; i++) {
        expect(points[i].value, equals(i.toDouble()));
      }
    });

    test('removes oldest point when adding beyond capacity', () {
      final now = DateTime.now();
      
      // Fill buffer to capacity
      for (int i = 0; i < bufferSize; i++) {
        buffer.add(TimeSeriesPoint(now.add(Duration(seconds: i)), i.toDouble()));
      }

      // Add one more point
      buffer.add(TimeSeriesPoint(now.add(Duration(seconds: bufferSize)), bufferSize.toDouble()));

      // Buffer should still be at max size
      expect(buffer.length, equals(bufferSize));
      
      // First point should be removed, values should be 1, 2, 3, 4, 5
      final points = buffer.points;
      for (int i = 0; i < bufferSize; i++) {
        expect(points[i].value, equals((i + 1).toDouble()));
      }
    });

    test('continues accepting data after reaching capacity', () {
      final now = DateTime.now();
      
      // Add 3x the buffer size
      for (int i = 0; i < bufferSize * 3; i++) {
        buffer.add(TimeSeriesPoint(now.add(Duration(seconds: i)), i.toDouble()));
        
        // Buffer should never exceed max size
        expect(buffer.length, lessThanOrEqualTo(bufferSize));
      }

      // Buffer should be at capacity
      expect(buffer.length, equals(bufferSize));
      
      // Should contain the most recent values: 10, 11, 12, 13, 14
      final points = buffer.points;
      for (int i = 0; i < bufferSize; i++) {
        expect(points[i].value, equals((bufferSize * 2 + i).toDouble()));
      }
    });

    test('removeOldData removes points before cutoff', () {
      final now = DateTime.now();
      
      // Add points with different timestamps
      for (int i = 0; i < bufferSize; i++) {
        buffer.add(TimeSeriesPoint(now.add(Duration(minutes: i)), i.toDouble()));
      }

      // Remove data older than 2 minutes from now
      final cutoff = now.add(Duration(minutes: 2));
      buffer.removeOldData(cutoff);

      // Should have 3 points left (minutes 2, 3, 4)
      expect(buffer.length, equals(3));
      expect(buffer.points.first.value, equals(2.0));
      expect(buffer.points.last.value, equals(4.0));
    });

    test('removeOldData handles empty buffer', () {
      final cutoff = DateTime.now();
      
      expect(() => buffer.removeOldData(cutoff), returnsNormally);
      expect(buffer.isEmpty, isTrue);
    });

    test('removeOldData handles all data being old', () {
      final now = DateTime.now();
      
      // Add old data
      for (int i = 0; i < bufferSize; i++) {
        buffer.add(TimeSeriesPoint(now.subtract(Duration(hours: i + 1)), i.toDouble()));
      }

      // Remove all data
      buffer.removeOldData(now);

      expect(buffer.isEmpty, isTrue);
      expect(buffer.length, equals(0));
    });

    test('clear empties the buffer', () {
      final now = DateTime.now();
      
      // Add some data
      for (int i = 0; i < 3; i++) {
        buffer.add(TimeSeriesPoint(now.add(Duration(seconds: i)), i.toDouble()));
      }

      expect(buffer.isEmpty, isFalse);
      
      buffer.clear();
      
      expect(buffer.isEmpty, isTrue);
      expect(buffer.length, equals(0));
      expect(buffer.points, isEmpty);
    });

    test('buffer maintains order when cycling at capacity', () {
      final now = DateTime.now();
      
      // Fill buffer and continue adding
      for (int i = 0; i < bufferSize * 2; i++) {
        buffer.add(TimeSeriesPoint(now.add(Duration(seconds: i)), i.toDouble()));
      }

      // Points should be in chronological order
      final points = buffer.points;
      for (int i = 1; i < points.length; i++) {
        expect(points[i].timestamp.isAfter(points[i - 1].timestamp), isTrue);
        expect(points[i].value > points[i - 1].value, isTrue);
      }
    });

    test('handles rapid continuous updates at capacity', () {
      final now = DateTime.now();
      const int totalUpdates = 10000; // Simulate many updates
      
      for (int i = 0; i < totalUpdates; i++) {
        buffer.add(TimeSeriesPoint(
          now.add(Duration(milliseconds: i)), 
          i.toDouble()
        ));
      }

      // Buffer should still be functional
      expect(buffer.length, equals(bufferSize));
      
      // Should contain the most recent values
      final points = buffer.points;
      expect(points.last.value, equals((totalUpdates - 1).toDouble()));
      expect(points.first.value, equals((totalUpdates - bufferSize).toDouble()));
    });

    test('timestamp tracking works correctly at capacity', () {
      final now = DateTime.now();
      
      // Fill buffer past capacity
      for (int i = 0; i < bufferSize * 2; i++) {
        buffer.add(TimeSeriesPoint(now.add(Duration(seconds: i)), i.toDouble()));
      }

      // Get the last timestamp
      final lastTimestamp = buffer.points.last.timestamp;
      
      // Add a new point with newer timestamp
      final newerTimestamp = lastTimestamp.add(Duration(seconds: 1));
      buffer.add(TimeSeriesPoint(newerTimestamp, 999.0));
      
      // The newest point should be present
      expect(buffer.points.last.timestamp, equals(newerTimestamp));
      expect(buffer.points.last.value, equals(999.0));
    });
  });
}