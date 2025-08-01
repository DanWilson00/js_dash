import 'dart:async';
import 'package:dart_mavlink/dialects/common.dart';
import '../interfaces/i_data_source.dart';
import '../core/service_locator.dart';
import 'mavlink_message_tracker.dart';

abstract class MavlinkDataProvider implements IDataSource, Disposable {
  final MavlinkMessageTracker _tracker = MavlinkMessageTracker();
  
  final StreamController<Heartbeat> _heartbeatController = StreamController<Heartbeat>.broadcast();
  final StreamController<SysStatus> _sysStatusController = StreamController<SysStatus>.broadcast();
  final StreamController<Attitude> _attitudeController = StreamController<Attitude>.broadcast();
  final StreamController<GlobalPositionInt> _gpsController = StreamController<GlobalPositionInt>.broadcast();
  final StreamController<VfrHud> _vfrHudController = StreamController<VfrHud>.broadcast();

  @override
  Stream<Heartbeat> get heartbeatStream => _heartbeatController.stream;
  @override
  Stream<SysStatus> get sysStatusStream => _sysStatusController.stream;
  @override
  Stream<Attitude> get attitudeStream => _attitudeController.stream;
  @override
  Stream<GlobalPositionInt> get gpsStream => _gpsController.stream;
  @override
  Stream<VfrHud> get vfrHudStream => _vfrHudController.stream;
  
  // Abstract methods that must be implemented by concrete classes
  @override
  Stream<dynamic> get messageStream;
  @override
  bool get isConnected;
  @override
  bool get isPaused;
  @override
  Future<void> initialize();
  @override
  Future<void> connect();
  @override
  Future<void> disconnect();
  @override
  void pause();
  @override
  void resume();

  void addMessage(dynamic message) {
    _tracker.trackMessage(message);
    
    if (message is Heartbeat && !_heartbeatController.isClosed) {
      _heartbeatController.add(message);
    } else if (message is SysStatus && !_sysStatusController.isClosed) {
      _sysStatusController.add(message);
    } else if (message is Attitude && !_attitudeController.isClosed) {
      _attitudeController.add(message);
    } else if (message is GlobalPositionInt && !_gpsController.isClosed) {
      _gpsController.add(message);
    } else if (message is VfrHud && !_vfrHudController.isClosed) {
      _vfrHudController.add(message);
    }
  }

  @override
  void dispose() {
    _heartbeatController.close();
    _sysStatusController.close();
    _attitudeController.close();
    _gpsController.close();
    _vfrHudController.close();
  }
  
  // Deprecated method - use dispose() instead
  @Deprecated('Use dispose() instead')
  void disposeStreams() => dispose();
}