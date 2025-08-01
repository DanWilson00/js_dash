import 'dart:async';
import 'package:dart_mavlink/dialects/common.dart';

/// Abstract interface for MAVLink data sources
/// Provides a unified interface for both real MAVLink connections and spoofing
abstract interface class IDataSource {
  /// Stream of incoming MAVLink messages
  Stream<dynamic> get messageStream;
  
  /// Stream for specific message types
  Stream<Heartbeat> get heartbeatStream;
  Stream<SysStatus> get sysStatusStream;
  Stream<Attitude> get attitudeStream;
  Stream<GlobalPositionInt> get gpsStream;
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
  void dispose();
}