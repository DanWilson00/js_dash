import 'dart:async';
import 'package:dart_mavlink/dialects/common.dart';
import 'mavlink_message_tracker.dart';

abstract class MavlinkDataProvider {
  final MavlinkMessageTracker _tracker = MavlinkMessageTracker();
  
  final StreamController<Heartbeat> _heartbeatController = StreamController<Heartbeat>.broadcast();
  final StreamController<SysStatus> _sysStatusController = StreamController<SysStatus>.broadcast();
  final StreamController<Attitude> _attitudeController = StreamController<Attitude>.broadcast();
  final StreamController<GlobalPositionInt> _gpsController = StreamController<GlobalPositionInt>.broadcast();
  final StreamController<VfrHud> _vfrHudController = StreamController<VfrHud>.broadcast();

  Stream<Heartbeat> get heartbeatStream => _heartbeatController.stream;
  Stream<SysStatus> get sysStatusStream => _sysStatusController.stream;
  Stream<Attitude> get attitudeStream => _attitudeController.stream;
  Stream<GlobalPositionInt> get gpsStream => _gpsController.stream;
  Stream<VfrHud> get vfrHudStream => _vfrHudController.stream;

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

  void disposeStreams() {
    _heartbeatController.close();
    _sysStatusController.close();
    _attitudeController.close();
    _gpsController.close();
    _vfrHudController.close();
  }
}