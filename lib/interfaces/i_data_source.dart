import 'dart:async';

import '../mavlink/mavlink.dart';
import 'disposable.dart';

/// Abstract interface for MAVLink data sources
/// Provides a unified interface for both real MAVLink connections and spoofing
abstract interface class IDataSource implements Disposable {
  /// Stream of incoming MAVLink messages
  Stream<MavlinkMessage> get messageStream;

  /// Get a filtered stream for a specific message name
  Stream<MavlinkMessage> streamByName(String name);

  /// Get a filtered stream for a specific message ID
  Stream<MavlinkMessage> streamById(int id);

  /// Connection state
  bool get isConnected;
  bool get isPaused;

  /// Connection management
  Future<void> initialize();
  Future<void> connect();
  Future<void> disconnect();

  /// Data flow control
  void pause();
  void resume();

  /// Cleanup resources
  @override
  void dispose();
}
