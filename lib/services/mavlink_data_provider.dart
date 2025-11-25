import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/common.dart';
import '../interfaces/i_data_source.dart';
import '../interfaces/disposable.dart';
import 'mavlink_message_tracker.dart';

abstract class MavlinkDataProvider implements IDataSource, Disposable {
  final MavlinkMessageTracker _tracker;

  // Stream controllers for specific message types
  final StreamController<Heartbeat> _heartbeatController =
      StreamController<Heartbeat>.broadcast();
  final StreamController<SysStatus> _sysStatusController =
      StreamController<SysStatus>.broadcast();
  final StreamController<Attitude> _attitudeController =
      StreamController<Attitude>.broadcast();
  final StreamController<GlobalPositionInt> _globalPositionController =
      StreamController<GlobalPositionInt>.broadcast();
  final StreamController<VfrHud> _vfrHudController =
      StreamController<VfrHud>.broadcast();

  MavlinkDataProvider({required MavlinkMessageTracker tracker})
    : _tracker = tracker;

  // Expose specific message streams
  @override
  Stream<Heartbeat> get heartbeatStream => _heartbeatController.stream;
  @override
  Stream<SysStatus> get sysStatusStream => _sysStatusController.stream;
  @override
  Stream<Attitude> get attitudeStream => _attitudeController.stream;
  @override
  Stream<GlobalPositionInt> get globalPositionStream =>
      _globalPositionController.stream;
  @override
  Stream<VfrHud> get vfrHudStream => _vfrHudController.stream;

  Stream<Map<String, MessageStats>> get messageStatsStream =>
      _tracker.statsStream;

  @protected
  void addMessage(dynamic message) {
    // Track message statistics
    if (message is MavlinkMessage) {
      _tracker.trackMessage(message);
    }

    // Dispatch to specific streams
    if (message is Heartbeat) {
      _heartbeatController.add(message);
    } else if (message is SysStatus) {
      _sysStatusController.add(message);
    } else if (message is Attitude) {
      _attitudeController.add(message);
    } else if (message is GlobalPositionInt) {
      _globalPositionController.add(message);
    } else if (message is VfrHud) {
      _vfrHudController.add(message);
    }
  }

  @override
  @mustCallSuper
  void dispose() {
    _heartbeatController.close();
    _sysStatusController.close();
    _attitudeController.close();
    _globalPositionController.close();
    _vfrHudController.close();
  }
}
