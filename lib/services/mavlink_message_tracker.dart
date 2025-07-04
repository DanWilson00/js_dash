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
    
    // Return cached fields if available and recent
    final tracker = MavlinkMessageTracker();
    final messageName = tracker._getMessageName(lastMessage!);
    final cachedFields = tracker._fieldCache[messageName];
    final lastUpdate = tracker._lastFieldUpdate[messageName];
    
    if (cachedFields != null && lastUpdate != null && 
        DateTime.now().difference(lastUpdate).inMilliseconds < 200) {
      return Map.from(cachedFields);
    }
    
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
  static const Duration _statsUpdateInterval = Duration(milliseconds: 100);
  
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
  
  // Caching
  final Map<String, Map<String, dynamic>> _fieldCache = {};
  final Map<String, DateTime> _lastFieldUpdate = {};

  void startTracking() {
    if (_isTracking) return;
    _isTracking = true;
    
    // Stream is available directly through _statsController
    
    // Update stats stream periodically
    _updateTimer = Timer.periodic(_statsUpdateInterval, (_) {
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
    
    // Cache field processing to avoid redundant calculations
    _updateFieldCache(messageName, _messageStats[messageName]!);
  }
  
  void _updateFieldCache(String messageName, MessageStats stats) {
    // Only update field cache if message has actually changed
    if (stats.lastMessage != null) {
      _fieldCache[messageName] = stats.getMessageFields();
    }
  }

  static final Map<Type, String> _messageTypeMap = {
    Heartbeat: 'HEARTBEAT',
    SysStatus: 'SYS_STATUS',
    Attitude: 'ATTITUDE',
    GlobalPositionInt: 'GLOBAL_POSITION_INT',
    VfrHud: 'VFR_HUD',
    SystemTime: 'SYSTEM_TIME',
    Ping: 'PING',
    ChangeOperatorControl: 'CHANGE_OPERATOR_CONTROL',
    ChangeOperatorControlAck: 'CHANGE_OPERATOR_CONTROL_ACK',
    AuthKey: 'AUTH_KEY',
    SetMode: 'SET_MODE',
    ParamRequestRead: 'PARAM_REQUEST_READ',
    ParamRequestList: 'PARAM_REQUEST_LIST',
    ParamValue: 'PARAM_VALUE',
    ParamSet: 'PARAM_SET',
    GpsRawInt: 'GPS_RAW_INT',
    GpsStatus: 'GPS_STATUS',
    ScaledImu: 'SCALED_IMU',
    RawImu: 'RAW_IMU',
    RawPressure: 'RAW_PRESSURE',
    ScaledPressure: 'SCALED_PRESSURE',
    AttitudeQuaternion: 'ATTITUDE_QUATERNION',
    LocalPositionNed: 'LOCAL_POSITION_NED',
    GlobalPositionIntCov: 'GLOBAL_POSITION_INT_COV',
    RcChannelsScaled: 'RC_CHANNELS_SCALED',
    RcChannelsRaw: 'RC_CHANNELS_RAW',
    ServoOutputRaw: 'SERVO_OUTPUT_RAW',
    MissionRequestPartialList: 'MISSION_REQUEST_PARTIAL_LIST',
    MissionWritePartialList: 'MISSION_WRITE_PARTIAL_LIST',
    MissionItem: 'MISSION_ITEM',
    MissionRequest: 'MISSION_REQUEST',
    MissionSetCurrent: 'MISSION_SET_CURRENT',
    MissionCurrent: 'MISSION_CURRENT',
    MissionRequestList: 'MISSION_REQUEST_LIST',
    MissionCount: 'MISSION_COUNT',
    MissionClearAll: 'MISSION_CLEAR_ALL',
    MissionItemReached: 'MISSION_ITEM_REACHED',
    MissionAck: 'MISSION_ACK',
    SetGpsGlobalOrigin: 'SET_GPS_GLOBAL_ORIGIN',
    GpsGlobalOrigin: 'GPS_GLOBAL_ORIGIN',
    ParamMapRc: 'PARAM_MAP_RC',
    MissionRequestInt: 'MISSION_REQUEST_INT',
    SafetySetAllowedArea: 'SAFETY_SET_ALLOWED_AREA',
    SafetyAllowedArea: 'SAFETY_ALLOWED_AREA',
    AttitudeQuaternionCov: 'ATTITUDE_QUATERNION_COV',
    NavControllerOutput: 'NAV_CONTROLLER_OUTPUT',
    LocalPositionNedCov: 'LOCAL_POSITION_NED_COV',
    RcChannels: 'RC_CHANNELS',
    RequestDataStream: 'REQUEST_DATA_STREAM',
    DataStream: 'DATA_STREAM',
    ManualControl: 'MANUAL_CONTROL',
    RcChannelsOverride: 'RC_CHANNELS_OVERRIDE',
    MissionItemInt: 'MISSION_ITEM_INT',
    CommandInt: 'COMMAND_INT',
    CommandLong: 'COMMAND_LONG',
    CommandAck: 'COMMAND_ACK',
  };

  String _getMessageName(MavlinkMessage message) {
    return _messageTypeMap[message.runtimeType] ?? 'MSG_${message.mavlinkMessageId}';
  }

  void clearStats() {
    _messageStats.clear();
    _fieldCache.clear();
    _lastFieldUpdate.clear();
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