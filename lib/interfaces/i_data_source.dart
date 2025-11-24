import 'dart:async';
import 'package:dart_mavlink/dialects/common.dart';
import 'disposable.dart';

/// Abstract interface for MAVLink data sources
/// Provides a unified interface for both real MAVLink connections and spoofing
abstract interface class IDataSource implements Disposable {
  /// Stream of incoming MAVLink messages
  Stream<dynamic> get messageStream;

  /// Stream for specific message types
  Stream<Heartbeat> get heartbeatStream;
  Stream<SysStatus> get sysStatusStream;
  Stream<Attitude> get attitudeStream;
  Stream<GlobalPositionInt> get globalPositionStream;
  Stream<VfrHud> get vfrHudStream;

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
