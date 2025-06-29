import 'dart:async';
import 'package:dart_mavlink/mavlink_message.dart';
import 'package:dart_mavlink/dialects/common.dart';

class MessageStats {
  int count = 0;
  DateTime firstReceived = DateTime.now();
  DateTime lastReceived = DateTime.now();
  MavlinkMessage? lastMessage;
  double frequency = 0.0;

  void updateMessage(MavlinkMessage message) {
    count++;
    lastReceived = DateTime.now();
    lastMessage = message;
    
    // Calculate frequency over the last 5 seconds
    final duration = lastReceived.difference(firstReceived);
    if (duration.inMilliseconds > 1000) {
      frequency = count / (duration.inMilliseconds / 1000.0);
    }
  }

  Map<String, dynamic> getMessageFields() {
    if (lastMessage == null) return {};
    
    final fields = <String, dynamic>{};
    
    if (lastMessage is Heartbeat) {
      final msg = lastMessage as Heartbeat;
      fields['Type'] = _getVehicleTypeName(msg.type);
      fields['Autopilot'] = _getAutopilotName(msg.autopilot);
      fields['Base Mode'] = '0x${msg.baseMode.toRadixString(16).toUpperCase()}';
      fields['Custom Mode'] = msg.customMode.toString();
      fields['System Status'] = _getSystemStatusName(msg.systemStatus);
      fields['MAVLink Version'] = msg.mavlinkVersion.toString();
    } else if (lastMessage is SysStatus) {
      final msg = lastMessage as SysStatus;
      fields['Battery Voltage'] = '${msg.voltageBattery / 1000.0} V';
      fields['Battery Current'] = '${msg.currentBattery / 100.0} A';
      fields['Battery Remaining'] = '${msg.batteryRemaining}%';
      fields['CPU Load'] = '${msg.load / 10.0}%';
      fields['Drop Rate'] = '${msg.dropRateComm / 100.0}%';
      fields['Errors Comm'] = msg.errorsComm.toString();
    } else if (lastMessage is Attitude) {
      final msg = lastMessage as Attitude;
      fields['Roll'] = '${(msg.roll * 180 / 3.14159).toStringAsFixed(2)}°';
      fields['Pitch'] = '${(msg.pitch * 180 / 3.14159).toStringAsFixed(2)}°';
      fields['Yaw'] = '${(msg.yaw * 180 / 3.14159).toStringAsFixed(2)}°';
      fields['Roll Speed'] = '${msg.rollspeed.toStringAsFixed(3)} rad/s';
      fields['Pitch Speed'] = '${msg.pitchspeed.toStringAsFixed(3)} rad/s';
      fields['Yaw Speed'] = '${msg.yawspeed.toStringAsFixed(3)} rad/s';
      fields['Time Boot'] = '${msg.timeBootMs} ms';
    } else if (lastMessage is GlobalPositionInt) {
      final msg = lastMessage as GlobalPositionInt;
      fields['Latitude'] = '${msg.lat / 1e7}°';
      fields['Longitude'] = '${msg.lon / 1e7}°';
      fields['Altitude'] = '${msg.alt / 1000.0} m';
      fields['Relative Alt'] = '${msg.relativeAlt / 1000.0} m';
      fields['Velocity X'] = '${msg.vx / 100.0} m/s';
      fields['Velocity Y'] = '${msg.vy / 100.0} m/s';
      fields['Velocity Z'] = '${msg.vz / 100.0} m/s';
      fields['Heading'] = '${msg.hdg / 100.0}°';
      fields['Time Boot'] = '${msg.timeBootMs} ms';
    } else if (lastMessage is VfrHud) {
      final msg = lastMessage as VfrHud;
      fields['Airspeed'] = '${msg.airspeed.toStringAsFixed(2)} m/s';
      fields['Groundspeed'] = '${msg.groundspeed.toStringAsFixed(2)} m/s';
      fields['Heading'] = '${msg.heading}°';
      fields['Throttle'] = '${msg.throttle}%';
      fields['Altitude'] = '${msg.alt.toStringAsFixed(2)} m';
      fields['Climb Rate'] = '${msg.climb.toStringAsFixed(2)} m/s';
    } else {
      // Generic field extraction for unknown message types
      fields['Message ID'] = lastMessage!.mavlinkMessageId.toString();
      fields['CRC Extra'] = lastMessage!.mavlinkCrcExtra.toString();
    }
    
    return fields;
  }

  String _getVehicleTypeName(int type) {
    switch (type) {
      case mavTypeGeneric: return 'Generic';
      case mavTypeFixedWing: return 'Fixed Wing';
      case mavTypeQuadrotor: return 'Quadrotor';
      case mavTypeCoaxial: return 'Coaxial';
      case mavTypeHelicopter: return 'Helicopter';
      case mavTypeAntennaTracker: return 'Antenna Tracker';
      case mavTypeGcs: return 'Ground Station';
      case mavTypeSubmarine: return 'Submarine';
      default: return 'Unknown ($type)';
    }
  }

  String _getAutopilotName(int autopilot) {
    switch (autopilot) {
      case mavAutopilotGeneric: return 'Generic';
      case mavAutopilotArdupilotmega: return 'ArduPilot';
      case mavAutopilotPx4: return 'PX4';
      default: return 'Unknown ($autopilot)';
    }
  }

  String _getSystemStatusName(int status) {
    switch (status) {
      case mavStateActive: return 'Active';
      case mavStateStandby: return 'Standby';
      case mavStateCritical: return 'Critical';
      case mavStateEmergency: return 'Emergency';
      case mavStatePoweroff: return 'Power Off';
      default: return 'Unknown ($status)';
    }
  }
}

class MavlinkMessageTracker {
  static MavlinkMessageTracker? _instance;
  factory MavlinkMessageTracker() => _instance ??= MavlinkMessageTracker._internal();
  MavlinkMessageTracker._internal();

  final Map<String, MessageStats> _messageStats = {};
  final StreamController<Map<String, MessageStats>> _statsController = 
      StreamController<Map<String, MessageStats>>.broadcast();

  Stream<Map<String, MessageStats>> get statsStream => _statsController.stream;
  Map<String, MessageStats> get currentStats => Map.from(_messageStats);

  Timer? _updateTimer;
  bool _isTracking = false;

  void startTracking() {
    if (_isTracking) return;
    _isTracking = true;
    
    // Update stats stream every 500ms
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!_statsController.isClosed) {
        _statsController.add(Map.from(_messageStats));
      }
    });
  }

  void stopTracking() {
    _isTracking = false;
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  void trackMessage(MavlinkMessage message) {
    if (!_isTracking) return;
    
    final messageName = _getMessageName(message);
    
    _messageStats.putIfAbsent(messageName, () => MessageStats());
    _messageStats[messageName]!.updateMessage(message);
  }

  String _getMessageName(MavlinkMessage message) {
    if (message is Heartbeat) return 'HEARTBEAT';
    if (message is SysStatus) return 'SYS_STATUS';
    if (message is Attitude) return 'ATTITUDE';
    if (message is GlobalPositionInt) return 'GLOBAL_POSITION_INT';
    if (message is VfrHud) return 'VFR_HUD';
    if (message is SystemTime) return 'SYSTEM_TIME';
    if (message is Ping) return 'PING';
    if (message is ChangeOperatorControl) return 'CHANGE_OPERATOR_CONTROL';
    if (message is ChangeOperatorControlAck) return 'CHANGE_OPERATOR_CONTROL_ACK';
    if (message is AuthKey) return 'AUTH_KEY';
    if (message is SetMode) return 'SET_MODE';
    if (message is ParamRequestRead) return 'PARAM_REQUEST_READ';
    if (message is ParamRequestList) return 'PARAM_REQUEST_LIST';
    if (message is ParamValue) return 'PARAM_VALUE';
    if (message is ParamSet) return 'PARAM_SET';
    if (message is GpsRawInt) return 'GPS_RAW_INT';
    if (message is GpsStatus) return 'GPS_STATUS';
    if (message is ScaledImu) return 'SCALED_IMU';
    if (message is RawImu) return 'RAW_IMU';
    if (message is RawPressure) return 'RAW_PRESSURE';
    if (message is ScaledPressure) return 'SCALED_PRESSURE';
    if (message is AttitudeQuaternion) return 'ATTITUDE_QUATERNION';
    if (message is LocalPositionNed) return 'LOCAL_POSITION_NED';
    if (message is GlobalPositionIntCov) return 'GLOBAL_POSITION_INT_COV';
    if (message is RcChannelsScaled) return 'RC_CHANNELS_SCALED';
    if (message is RcChannelsRaw) return 'RC_CHANNELS_RAW';
    if (message is ServoOutputRaw) return 'SERVO_OUTPUT_RAW';
    if (message is MissionRequestPartialList) return 'MISSION_REQUEST_PARTIAL_LIST';
    if (message is MissionWritePartialList) return 'MISSION_WRITE_PARTIAL_LIST';
    if (message is MissionItem) return 'MISSION_ITEM';
    if (message is MissionRequest) return 'MISSION_REQUEST';
    if (message is MissionSetCurrent) return 'MISSION_SET_CURRENT';
    if (message is MissionCurrent) return 'MISSION_CURRENT';
    if (message is MissionRequestList) return 'MISSION_REQUEST_LIST';
    if (message is MissionCount) return 'MISSION_COUNT';
    if (message is MissionClearAll) return 'MISSION_CLEAR_ALL';
    if (message is MissionItemReached) return 'MISSION_ITEM_REACHED';
    if (message is MissionAck) return 'MISSION_ACK';
    if (message is SetGpsGlobalOrigin) return 'SET_GPS_GLOBAL_ORIGIN';
    if (message is GpsGlobalOrigin) return 'GPS_GLOBAL_ORIGIN';
    if (message is ParamMapRc) return 'PARAM_MAP_RC';
    if (message is MissionRequestInt) return 'MISSION_REQUEST_INT';
    if (message is SafetySetAllowedArea) return 'SAFETY_SET_ALLOWED_AREA';
    if (message is SafetyAllowedArea) return 'SAFETY_ALLOWED_AREA';
    if (message is AttitudeQuaternionCov) return 'ATTITUDE_QUATERNION_COV';
    if (message is NavControllerOutput) return 'NAV_CONTROLLER_OUTPUT';
    if (message is GlobalPositionIntCov) return 'GLOBAL_POSITION_INT_COV';
    if (message is LocalPositionNedCov) return 'LOCAL_POSITION_NED_COV';
    if (message is RcChannels) return 'RC_CHANNELS';
    if (message is RequestDataStream) return 'REQUEST_DATA_STREAM';
    if (message is DataStream) return 'DATA_STREAM';
    if (message is ManualControl) return 'MANUAL_CONTROL';
    if (message is RcChannelsOverride) return 'RC_CHANNELS_OVERRIDE';
    if (message is MissionItemInt) return 'MISSION_ITEM_INT';
    if (message is VfrHud) return 'VFR_HUD';
    if (message is CommandInt) return 'COMMAND_INT';
    if (message is CommandLong) return 'COMMAND_LONG';
    if (message is CommandAck) return 'COMMAND_ACK';
    
    // Fallback for unknown message types
    return 'MSG_${message.mavlinkMessageId}';
  }

  void clearStats() {
    _messageStats.clear();
    if (!_statsController.isClosed) {
      _statsController.add({});
    }
  }

  void dispose() {
    stopTracking();
    if (!_statsController.isClosed) {
      _statsController.close();
    }
  }

  // For testing - stop tracking and clean up completely
  static void resetInstanceForTesting() {
    if (_instance != null) {
      _instance!.stopTracking();
      if (!_instance!._statsController.isClosed) {
        _instance!._statsController.close();
      }
      _instance = null;
    }
  }
}