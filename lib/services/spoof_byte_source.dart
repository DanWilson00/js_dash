import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/common.dart';
import '../interfaces/i_byte_source.dart';

/// Spoof implementation of IByteSource
/// Generates fake MAVLink byte streams for testing without real hardware
/// This allows testing the entire MAVLink parsing pipeline
class SpoofByteSource implements IByteSource {
  final int systemId;
  final int componentId;

  Timer? _fastTelemetryTimer;
  Timer? _slowTelemetryTimer;
  Timer? _heartbeatTimer;

  final StreamController<Uint8List> _bytesController =
      StreamController<Uint8List>.broadcast();

  bool _isConnected = false;
  int _sequenceNumber = 0;

  // Telemetry simulation state
  double _altitude = 0.0;
  double _groundSpeed = 0.0;
  double _heading = 0.0;
  double _pitch = 0.0;
  double _roll = 0.0;
  double _yaw = 0.0;
  double _batteryVoltage = 12.6;
  int _simulationTime = 0;

  // GPS simulation state
  double _latitude = 34.0522;
  double _longitude = -118.2437;

  // Dashboard simulation state
  double _rpm = 1000.0;
  double _rpmDirection = 1.0;

  SpoofByteSource({
    this.systemId = 1,
    this.componentId = 1,
  });

  @override
  Stream<Uint8List> get bytes => _bytesController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> connect() async {
    await disconnect();

    _isConnected = true;

    // Fast telemetry at 10 Hz (attitude, position, HUD)
    _fastTelemetryTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _generateFastTelemetry(),
    );

    // Slow telemetry at 1 Hz (SYS_STATUS)
    _slowTelemetryTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _generateSlowTelemetry(),
    );

    // Heartbeat at 1 Hz
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _generateHeartbeat(),
    );
  }

  @override
  Future<void> disconnect() async {
    _fastTelemetryTimer?.cancel();
    _slowTelemetryTimer?.cancel();
    _heartbeatTimer?.cancel();
    _fastTelemetryTimer = null;
    _slowTelemetryTimer = null;
    _heartbeatTimer = null;
    _isConnected = false;
  }

  @override
  void dispose() {
    disconnect();
    _bytesController.close();
  }

  void _emitMessage(MavlinkMessage message) {
    if (!_isConnected || _bytesController.isClosed) return;

    final frame = MavlinkFrame.v2(
      _sequenceNumber++,
      systemId,
      componentId,
      message,
    );

    final bytes = frame.serialize();
    _bytesController.add(Uint8List.fromList(bytes));
  }

  void _generateFastTelemetry() {
    if (!_isConnected) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    _simulationTime += 100;

    // Simulate realistic vehicle movement
    _altitude += (DateTime.now().millisecond % 100 - 50) / 1000.0;
    _altitude = _altitude.clamp(0.0, 100.0);

    _groundSpeed += (DateTime.now().millisecond % 60 - 30) / 100.0;
    _groundSpeed = _groundSpeed.clamp(5.0, 25.0);

    // Create a figure-8 pattern with some randomness
    final timeInSeconds = _simulationTime / 1000.0;
    final baseHeading = (timeInSeconds * 15) % 360;
    final headingVariation = 30 * math.sin(timeInSeconds * 0.5);
    _heading = (baseHeading + headingVariation) % 360.0;
    if (_heading < 0) _heading += 360.0;

    // Update GPS position based on movement
    final metersPerDegreeLatitude = 111320.0;
    final metersPerDegreeLongitude =
        111320.0 * math.cos(_latitude * math.pi / 180.0);

    final speedMs = _groundSpeed;
    final deltaTimeSeconds = 0.1;
    final distanceMeters = speedMs * deltaTimeSeconds;
    final headingRadians = _heading * math.pi / 180.0;

    final deltaLatDegrees =
        (distanceMeters * math.cos(headingRadians)) / metersPerDegreeLatitude;
    final deltaLonDegrees =
        (distanceMeters * math.sin(headingRadians)) / metersPerDegreeLongitude;

    _latitude += deltaLatDegrees;
    _longitude += deltaLonDegrees;

    // Keep in reasonable bounds
    _latitude = _latitude.clamp(33.9, 34.2);
    _longitude = _longitude.clamp(-118.5, -118.0);

    _pitch += (DateTime.now().millisecond % 10 - 5) / 100.0;
    _pitch = _pitch.clamp(-15.0, 15.0);

    _roll += (DateTime.now().millisecond % 10 - 5) / 100.0;
    _roll = _roll.clamp(-20.0, 20.0);

    _yaw = _heading * math.pi / 180.0;

    // Simulate RPM changes
    _rpm += _rpmDirection * (10 + (DateTime.now().millisecond % 30));
    if (_rpm >= 7500) {
      _rpmDirection = -1.0;
    } else if (_rpm <= 1500) {
      _rpmDirection = 1.0;
    }
    _rpm = _rpm.clamp(1000.0, 8000.0);

    // Generate messages
    _emitMessage(GlobalPositionInt(
      timeBootMs: now,
      lat: (_latitude * 1e7).round(),
      lon: (_longitude * 1e7).round(),
      alt: (_altitude * 1000).round(),
      relativeAlt: (_altitude * 1000).round(),
      vx: (_groundSpeed * math.cos(headingRadians) * 100).round(),
      vy: (_groundSpeed * math.sin(headingRadians) * 100).round(),
      vz: 0,
      hdg: (_heading * 100).round(),
    ));

    _emitMessage(Attitude(
      timeBootMs: now,
      roll: _roll * math.pi / 180.0,
      pitch: _pitch * math.pi / 180.0,
      yaw: _yaw,
      rollspeed: 0.0,
      pitchspeed: 0.0,
      yawspeed: 0.0,
    ));

    _emitMessage(VfrHud(
      airspeed: _groundSpeed,
      groundspeed: _groundSpeed,
      heading: _heading.round(),
      throttle: 50 + (DateTime.now().millisecond % 40 - 20),
      alt: _altitude,
      climb: (DateTime.now().millisecond % 100 - 50) / 50.0,
    ));
  }

  void _generateSlowTelemetry() {
    if (!_isConnected) return;

    _batteryVoltage = 12.6 + (DateTime.now().millisecond % 100 - 50) / 1000.0;
    _batteryVoltage = _batteryVoltage.clamp(10.0, 13.0);

    _emitMessage(SysStatus(
      onboardControlSensorsPresent: 0x7FF,
      onboardControlSensorsEnabled: 0x7FF,
      onboardControlSensorsHealth: 0x7FF,
      load: 100,
      voltageBattery: (_batteryVoltage * 1000).round(),
      currentBattery: -1,
      batteryRemaining: 85,
      dropRateComm: 0,
      errorsComm: 0,
      errorsCount1: 0,
      errorsCount2: 0,
      errorsCount3: 0,
      errorsCount4: 0,
      onboardControlSensorsPresentExtended: 0,
      onboardControlSensorsEnabledExtended: 0,
      onboardControlSensorsHealthExtended: 0,
    ));
  }

  void _generateHeartbeat() {
    if (!_isConnected) return;

    _emitMessage(Heartbeat(
      type: mavTypeGroundRover,
      autopilot: mavAutopilotGeneric,
      baseMode: 0,
      customMode: 0,
      systemStatus: 0,
      mavlinkVersion: 3,
    ));
  }

  // Expose simulation values for dashboard compatibility
  double get currentRPM => _rpm;
  double get currentSpeed => _groundSpeed;
  double get currentHeading => _heading;
  double get currentAltitude => _altitude;
}
