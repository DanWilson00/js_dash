/// Connection state enumeration
enum ConnectionState { disconnected, connecting, connected, error, paused }

/// Connection status information
class ConnectionStatus {
  final ConnectionState state;
  final String message;
  final DateTime timestamp;
  final String? errorDetails;

  const ConnectionStatus({
    required this.state,
    required this.message,
    required this.timestamp,
    this.errorDetails,
  });

  bool get isConnected => state == ConnectionState.connected;
  bool get isPaused => state == ConnectionState.paused;
  bool get hasError => state == ConnectionState.error;
}
