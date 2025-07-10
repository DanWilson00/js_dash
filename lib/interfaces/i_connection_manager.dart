import 'dart:async';

/// Connection state enumeration
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  error,
  paused,
}

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

/// Abstract interface for connection management
/// Handles switching between different data sources (real MAVLink vs spoofing)
abstract interface class IConnectionManager {
  /// Current connection status
  ConnectionStatus get currentStatus;
  
  /// Stream of connection status changes
  Stream<ConnectionStatus> get statusStream;
  
  /// Connection management
  Future<void> connect();
  Future<void> disconnect();
  
  /// Data flow control
  void pause();
  void resume();
  
  /// Check if data has been received recently
  bool hasRecentData([Duration? within]);
  
  /// Cleanup resources
  void dispose();
}