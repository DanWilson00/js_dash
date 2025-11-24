import 'dart:async';
import '../core/connection_config.dart';
import '../core/connection_status.dart';
import 'disposable.dart';

/// Abstract interface for connection management
/// Handles switching between different data sources (real MAVLink vs spoofing)
abstract interface class IConnectionManager implements Disposable {
  /// Current connection status
  ConnectionStatus get currentStatus;

  /// Stream of connection status changes
  Stream<ConnectionStatus> get statusStream;

  /// Connection management
  Future<bool> connect(ConnectionConfig config);
  Future<void> disconnect();

  /// Data flow control
  void pause();
  void resume();

  /// Check if data has been received recently
  bool hasRecentData([Duration? within]);

  /// Cleanup resources
  @override
  void dispose();
}
