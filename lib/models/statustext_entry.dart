/// Model for a STATUSTEXT MAVLink message entry.
class StatusTextEntry {
  final DateTime timestamp;
  final int severity;
  final String severityName;
  final String text;

  const StatusTextEntry({
    required this.timestamp,
    required this.severity,
    required this.severityName,
    required this.text,
  });

  /// Get a short severity label for display.
  String get severityLabel {
    // Strip "MAV_SEVERITY_" prefix if present
    if (severityName.startsWith('MAV_SEVERITY_')) {
      return severityName.substring(13);
    }
    return severityName;
  }

  /// Format timestamp as HH:MM:SS.
  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }
}
