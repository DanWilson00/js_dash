import 'dart:async';
import 'dart:math';
import 'package:dart_mavlink/dialects/common.dart';
import 'mavlink_message_tracker.dart';

class MavlinkSpoofService {
  static MavlinkSpoofService? _instance;
  factory MavlinkSpoofService() => _instance ??= MavlinkSpoofService._internal();
  MavlinkSpoofService._internal();
  
  // For testing - allows creating fresh instances
  MavlinkSpoofService.forTesting();

  Timer? _heartbeatTimer;
  Timer? _attitudeTimer;
  Timer? _gpsTimer;
  Timer? _sysStatusTimer;
  Timer? _vfrHudTimer;

  final Random _random = Random();
  bool _isRunning = false;
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

  bool get isRunning => _isRunning;

  double _roll = 0.0;
  double _pitch = 0.0;
  double _yaw = 0.0;
  double _lat = 37.7749; // San Francisco Bay area coordinates for testing
  double _lon = -122.4194;
  double _alt = 10.0; // 10 meters altitude (submersible depth)
  double _speed = 2.5; // 2.5 m/s cruising speed
  final int _batteryVoltage = 24000; // 24V in millivolts
  double _heading = 0.0;

  void startSpoofing({Duration? interval}) {
    if (_isRunning) return;
    
    _isRunning = true;
    final heartbeatInterval = interval ?? const Duration(seconds: 1);
    final fastInterval = Duration(milliseconds: heartbeatInterval.inMilliseconds ~/ 5); // 5Hz for telemetry

    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) => _generateHeartbeat());
    _sysStatusTimer = Timer.periodic(heartbeatInterval, (_) => _generateSysStatus());
    _attitudeTimer = Timer.periodic(fastInterval, (_) => _generateAttitude());
    _gpsTimer = Timer.periodic(fastInterval, (_) => _generateGPS());
    _vfrHudTimer = Timer.periodic(fastInterval, (_) => _generateVfrHud());
  }

  void stopSpoofing() {
    _isRunning = false;
    _heartbeatTimer?.cancel();
    _attitudeTimer?.cancel();
    _gpsTimer?.cancel();
    _sysStatusTimer?.cancel();
    _vfrHudTimer?.cancel();
    
    // Clear timers to prevent memory leaks
    _heartbeatTimer = null;
    _attitudeTimer = null;
    _gpsTimer = null;
    _sysStatusTimer = null;
    _vfrHudTimer = null;
  }

  void _generateHeartbeat() {
    if (!_isRunning || _heartbeatController.isClosed) return;
    
    final heartbeat = Heartbeat(
      type: mavTypeSubmarine, // Submarine type for submersible jetski
      autopilot: mavAutopilotArdupilotmega,
      baseMode: mavModeFlagSafetyArmed | mavModeFlagManualInputEnabled,
      customMode: 0,
      systemStatus: mavStateActive,
      mavlinkVersion: 3,
    );
    _tracker.trackMessage(heartbeat);
    _heartbeatController.add(heartbeat);
  }

  void _generateSysStatus() {
    if (!_isRunning || _sysStatusController.isClosed) return;
    
    final batteryRemaining = 50 + _random.nextInt(50); // 50-100% battery
    final sysStatus = SysStatus(
      onboardControlSensorsPresent: 0x3FF, // All sensors present
      onboardControlSensorsEnabled: 0x3FF, // All sensors enabled
      onboardControlSensorsHealth: 0x3FF, // All sensors healthy
      load: _random.nextInt(500), // CPU load 0-50%
      voltageBattery: _batteryVoltage,
      currentBattery: 5000 + _random.nextInt(3000), // 5-8A current draw
      batteryRemaining: batteryRemaining,
      dropRateComm: 0,
      errorsComm: 0,
      errorsCount1: 0,
      errorsCount2: 0,
      errorsCount3: 0,
      errorsCount4: 0,
      onboardControlSensorsPresentExtended: 0,
      onboardControlSensorsEnabledExtended: 0,
      onboardControlSensorsHealthExtended: 0,
    );
    _tracker.trackMessage(sysStatus);
    _sysStatusController.add(sysStatus);
  }

  void _generateAttitude() {
    if (!_isRunning || _attitudeController.isClosed) return;
    
    final time = DateTime.now().millisecondsSinceEpoch;
    
    // Simulate gentle rolling motion typical of water vehicle
    _roll += (_random.nextDouble() - 0.5) * 0.02;
    _roll = _roll.clamp(-0.2, 0.2); // ±11.5 degrees max roll
    
    _pitch += (_random.nextDouble() - 0.5) * 0.015;
    _pitch = _pitch.clamp(-0.15, 0.15); // ±8.6 degrees max pitch
    
    _yaw += (_random.nextDouble() - 0.5) * 0.01;
    if (_yaw > pi) _yaw -= 2 * pi;
    if (_yaw < -pi) _yaw += 2 * pi;

    final attitude = Attitude(
      timeBootMs: time,
      roll: _roll,
      pitch: _pitch,
      yaw: _yaw,
      rollspeed: (_random.nextDouble() - 0.5) * 0.1,
      pitchspeed: (_random.nextDouble() - 0.5) * 0.1,
      yawspeed: (_random.nextDouble() - 0.5) * 0.05,
    );
    _tracker.trackMessage(attitude);
    _attitudeController.add(attitude);
  }

  void _generateGPS() {
    if (!_isRunning || _gpsController.isClosed) return;
    
    final time = DateTime.now().millisecondsSinceEpoch;
    
    // Simulate slow movement pattern
    _lat += (_random.nextDouble() - 0.5) * 0.00001; // Small lat changes
    _lon += (_random.nextDouble() - 0.5) * 0.00001; // Small lon changes
    _alt = 5.0 + _random.nextDouble() * 10.0; // 5-15m depth variation
    
    final gps = GlobalPositionInt(
      timeBootMs: time,
      lat: (_lat * 1e7).round(), // Convert to 1E7 degrees
      lon: (_lon * 1e7).round(),
      alt: (_alt * 1000).round(), // Convert to mm
      relativeAlt: (_alt * 1000).round(),
      vx: ((_random.nextDouble() - 0.5) * 200).round(), // ±1 m/s in cm/s
      vy: ((_random.nextDouble() - 0.5) * 200).round(),
      vz: ((_random.nextDouble() - 0.5) * 50).round(), // ±0.5 m/s vertical
      hdg: (_heading * 100).round(), // Convert to centidegrees
    );
    _tracker.trackMessage(gps);
    _gpsController.add(gps);
  }

  void _generateVfrHud() {
    if (!_isRunning || _vfrHudController.isClosed) return;
    
    _speed = 2.0 + _random.nextDouble() * 2.0; // 2-4 m/s speed variation
    _heading += (_random.nextDouble() - 0.5) * 2.0; // Gradual heading change
    if (_heading < 0) _heading += 360;
    if (_heading >= 360) _heading -= 360;

    final vfrHud = VfrHud(
      airspeed: _speed, // Actually water speed for submersible
      groundspeed: _speed,
      heading: _heading.round(),
      throttle: 40 + _random.nextInt(40), // 40-80% throttle
      alt: _alt,
      climb: (_random.nextDouble() - 0.5) * 0.5, // ±0.5 m/s climb rate
    );
    _tracker.trackMessage(vfrHud);
    _vfrHudController.add(vfrHud);
  }

  void dispose() {
    stopSpoofing();
    _heartbeatController.close();
    _sysStatusController.close();
    _attitudeController.close();
    _gpsController.close();
    _vfrHudController.close();
  }

  // For testing - reset singleton instance
  static void resetInstanceForTesting() {
    _instance?.dispose();
    _instance = null;
  }
}