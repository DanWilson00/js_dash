import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/common.dart';
import 'mavlink_data_provider.dart';

/// USB Serial Spoof Service that simulates realistic MAVLink communication
/// over a virtual serial port with configurable timing and characteristics
class UsbSerialSpoofService extends MavlinkDataProvider {
  static UsbSerialSpoofService? _instance;
  factory UsbSerialSpoofService() => _instance ??= UsbSerialSpoofService._internal();
  UsbSerialSpoofService._internal() : _dialect = MavlinkDialectCommon();

  final MavlinkDialectCommon _dialect;
  MavlinkParser? _parser;
  
  Timer? _fastTelemetryTimer;  // 10 Hz for attitude, position, HUD
  Timer? _slowTelemetryTimer;  // 1 Hz for SYS_STATUS
  Timer? _heartbeatTimer;      // 1 Hz for HEARTBEAT
  Timer? _serialTransmissionTimer;
  
  final StreamController<MavlinkFrame> _frameController = StreamController<MavlinkFrame>.broadcast();
  final StreamController<Uint8List> _rawDataController = StreamController<Uint8List>.broadcast();
  
  // Serial simulation parameters
  int _baudRate = 57600; // Common MAVLink baud rate
  int _systemId = 1;
  int _componentId = 1;
  bool _isConnected = false;
  bool _isPaused = false;
  bool _isInitialized = false;
  
  // Buffer for realistic byte streaming
  final List<int> _transmissionBuffer = [];
  static const int _bytesPerTransmission = 64; // Realistic USB serial chunk size
  
  // Telemetry simulation state
  double _altitude = 0.0;
  double _groundSpeed = 0.0;
  double _heading = 0.0;
  double _pitch = 0.0;
  double _roll = 0.0;
  double _yaw = 0.0;
  double _batteryVoltage = 12.6;
  int _sequenceNumber = 0;
  
  // GPS simulation state for realistic movement
  double _latitude = 34.0522; // Los Angeles area starting point
  double _longitude = -118.2437;
  double _course = 90.0; // Initial course in degrees (East)
  int _simulationTime = 0; // Time counter for movement patterns
  
  // Dashboard simulation state
  double _rpm = 1000.0;
  double _rpmDirection = 1.0; // 1 for increasing, -1 for decreasing
  double _portWingPosition = 0.0; // -100 to +100 (degrees or percentage)
  double _starboardWingPosition = 0.0; // -100 to +100 (degrees or percentage)

  Stream<MavlinkFrame> get frameStream => _frameController.stream;
  Stream<Uint8List> get rawDataStream => _rawDataController.stream;
  bool get isConnected => _isConnected;
  bool get isPaused => _isPaused;
  
  // Dashboard data getters (for compatibility with dashboard)
  bool get isRunning => _isConnected;
  double get currentRPM => _rpm;
  double get currentSpeed => _groundSpeed;
  double get portWingPosition => _portWingPosition;
  double get starboardWingPosition => _starboardWingPosition;
  
  /// Initialize the spoof service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _parser ??= MavlinkParser(_dialect);
    
    _parser!.stream.listen((MavlinkFrame frame) {
      _frameController.add(frame);
      addMessage(frame.message);
    });
    
    _isInitialized = true;
  }

  /// Start spoofing with specified parameters
  Future<void> startSpoofing({
    int baudRate = 57600,
    int systemId = 1,
    int componentId = 1,
  }) async {
    if (_isConnected) {
      await stopSpoofing();
    }
    
    _baudRate = baudRate;
    _systemId = systemId;
    _componentId = componentId;
    _isConnected = true;
    _isPaused = false;
    
    // Calculate realistic transmission timing based on baud rate
    // Each MAVLink message is typically 20-40 bytes
    // At 57600 baud, that's about 5760 bytes/second
    // So we can transmit roughly 150-250 messages per second
    // We'll be more conservative and limit to realistic rates
    const transmissionIntervalMs = 5; // 200 Hz transmission rate
    
    // Start fast telemetry at 10 Hz (attitude, position, HUD)
    _fastTelemetryTimer = Timer.periodic(
      const Duration(milliseconds: 100),  // 10 Hz
      (_) => _generateFastTelemetryMessages(),
    );
    
    // Start slow telemetry at 1 Hz (SYS_STATUS)
    _slowTelemetryTimer = Timer.periodic(
      const Duration(seconds: 1),  // 1 Hz
      (_) => _generateSlowTelemetryMessages(),
    );
    
    // Start heartbeat generation at 1 Hz
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 1),  // 1 Hz
      (_) => _generateHeartbeatMessage(),
    );
    
    // Start serial transmission simulation
    _serialTransmissionTimer = Timer.periodic(
      Duration(milliseconds: transmissionIntervalMs),
      (_) => _transmitBufferedData(),
    );
  }

  /// Stop spoofing
  Future<void> stopSpoofing() async {
    _fastTelemetryTimer?.cancel();
    _slowTelemetryTimer?.cancel();
    _heartbeatTimer?.cancel();
    _serialTransmissionTimer?.cancel();
    
    _transmissionBuffer.clear();
    _isConnected = false;
    _isPaused = false;
  }

  /// Pause/resume data generation
  void setPaused(bool paused) {
    _isPaused = paused;
  }

  /// Generate fast telemetry messages at 10 Hz (attitude, position, HUD)
  void _generateFastTelemetryMessages() {
    if (_isPaused || !_isConnected) return;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    _simulationTime += 100; // Increment by 100ms each call (10 Hz)
    
    // Simulate realistic vehicle movement
    _altitude += (DateTime.now().millisecond % 100 - 50) / 1000.0;
    _altitude = _altitude.clamp(0.0, 100.0);
    
    _groundSpeed += (DateTime.now().millisecond % 60 - 30) / 100.0;
    _groundSpeed = _groundSpeed.clamp(5.0, 25.0); // Keep vehicle moving
    
    // Simulate course changes - gentle turns and occasional direction changes
    final timeInSeconds = _simulationTime / 1000.0;
    
    // Create a figure-8 pattern with some randomness
    final baseHeading = (timeInSeconds * 15) % 360; // 15 degrees per second rotation
    final headingVariation = 30 * math.sin(timeInSeconds * 0.5); // ±30 degree swing
    _heading = (baseHeading + headingVariation) % 360.0;
    if (_heading < 0) _heading += 360.0;
    
    _course = _heading; // Course follows heading
    
    // Update GPS position based on movement
    // Convert speed from m/s to degrees per second (approximate)
    final metersPerDegreeLatitude = 111320.0; // Approximate meters per degree latitude
    final metersPerDegreeLongitude = 111320.0 * math.cos(_latitude * math.pi / 180.0);
    
    final speedMs = _groundSpeed; // Ground speed in m/s
    final deltaTimeSeconds = 0.1; // 100ms = 0.1 seconds
    
    // Calculate movement in meters
    final distanceMeters = speedMs * deltaTimeSeconds;
    final headingRadians = _heading * math.pi / 180.0;
    
    // Update position
    final deltaLatDegrees = (distanceMeters * math.cos(headingRadians)) / metersPerDegreeLatitude;
    final deltaLonDegrees = (distanceMeters * math.sin(headingRadians)) / metersPerDegreeLongitude;
    
    _latitude += deltaLatDegrees;
    _longitude += deltaLonDegrees;
    
    // Keep vehicle in reasonable bounds (around LA area)
    _latitude = _latitude.clamp(33.9, 34.2);
    _longitude = _longitude.clamp(-118.5, -118.0);
    
    _pitch += (DateTime.now().millisecond % 10 - 5) / 100.0;
    _pitch = _pitch.clamp(-15.0, 15.0);
    
    _roll += (DateTime.now().millisecond % 10 - 5) / 100.0;
    _roll = _roll.clamp(-20.0, 20.0);
    
    _yaw = _heading * 3.14159 / 180.0; // Convert to radians
    
    // Simulate RPM changes (realistic jetski RPM: 1000-8000)
    _rpm += _rpmDirection * (10 + (DateTime.now().millisecond % 30));
    if (_rpm >= 7500) {
      _rpmDirection = -1.0; // Start decreasing
    } else if (_rpm <= 1500) {
      _rpmDirection = 1.0; // Start increasing
    }
    _rpm = _rpm.clamp(1000.0, 8000.0);
    
    // Simulate wing positions (hydrofoils adjusting based on speed and turns)
    final wingAdjustment = _groundSpeed * 2.0; // More speed = more wing adjustment
    final turnAdjustment = (_heading % 360 - 180).abs() / 10.0; // Turn effects
    
    _portWingPosition = (wingAdjustment + turnAdjustment) * math.sin(timeInSeconds * 0.5);
    _starboardWingPosition = (wingAdjustment - turnAdjustment) * math.cos(timeInSeconds * 0.3);
    
    _portWingPosition = _portWingPosition.clamp(-100.0, 100.0);
    _starboardWingPosition = _starboardWingPosition.clamp(-100.0, 100.0);
    
    // Generate GLOBAL_POSITION_INT message with moving coordinates
    final globalPosMsg = GlobalPositionInt(
      timeBootMs: now,
      lat: (_latitude * 1e7).round(), // Convert to 1E7 format
      lon: (_longitude * 1e7).round(), // Convert to 1E7 format
      alt: (_altitude * 1000).round(),
      relativeAlt: (_altitude * 1000).round(),
      vx: (_groundSpeed * math.cos(headingRadians) * 100).round(), // North velocity in cm/s
      vy: (_groundSpeed * math.sin(headingRadians) * 100).round(), // East velocity in cm/s
      vz: 0, // No vertical velocity
      hdg: (_heading * 100).round(),
    );
    
    // Generate ATTITUDE message
    final attitudeMsg = Attitude(
      timeBootMs: now,
      roll: _roll * 3.14159 / 180.0,
      pitch: _pitch * 3.14159 / 180.0,
      yaw: _yaw,
      rollspeed: 0.0,
      pitchspeed: 0.0,
      yawspeed: 0.0,
    );
    
    // Generate VFR_HUD message for dash display
    final vfrHudMsg = VfrHud(
      airspeed: _groundSpeed,
      groundspeed: _groundSpeed,
      heading: _heading.round(),
      throttle: 50 + (DateTime.now().millisecond % 40 - 20), // 30-70% throttle
      alt: _altitude,
      climb: (DateTime.now().millisecond % 100 - 50) / 50.0, // ±1 m/s climb rate
    );
    
    // Queue messages for transmission
    _queueMessageForTransmission(globalPosMsg);
    _queueMessageForTransmission(attitudeMsg);
    _queueMessageForTransmission(vfrHudMsg);
  }
  
  /// Generate slow telemetry messages at 1 Hz (SYS_STATUS)
  void _generateSlowTelemetryMessages() {
    if (_isPaused || !_isConnected) return;
    
    // Update battery voltage slowly
    _batteryVoltage = 12.6 + (DateTime.now().millisecond % 100 - 50) / 1000.0;
    _batteryVoltage = _batteryVoltage.clamp(10.0, 13.0);
    
    // Generate SYS_STATUS message
    final sysStatusMsg = SysStatus(
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
    );
    
    // Queue message for transmission
    _queueMessageForTransmission(sysStatusMsg);
  }

  /// Generate heartbeat message
  void _generateHeartbeatMessage() {
    if (_isPaused || !_isConnected) return;
    
    final heartbeatMsg = Heartbeat(
      type: mavTypeGroundRover,
      autopilot: mavAutopilotGeneric,
      baseMode: 0,
      customMode: 0,
      systemStatus: 0,
      mavlinkVersion: 3,
    );
    
    _queueMessageForTransmission(heartbeatMsg);
  }

  /// Queue a message for realistic serial transmission
  void _queueMessageForTransmission(MavlinkMessage message) {
    final frame = MavlinkFrame.v2(
      _sequenceNumber++,
      _systemId,
      _componentId,
      message,
    );
    
    final bytes = frame.serialize();
    _transmissionBuffer.addAll(bytes);
  }

  /// Transmit buffered data at realistic serial speeds
  void _transmitBufferedData() {
    if (_transmissionBuffer.isEmpty || !_isConnected) return;
    
    // Determine how many bytes to transmit this cycle
    final bytesToTransmit = _transmissionBuffer.length > _bytesPerTransmission 
        ? _bytesPerTransmission 
        : _transmissionBuffer.length;
    
    // Extract bytes for transmission
    final dataToTransmit = Uint8List.fromList(
      _transmissionBuffer.take(bytesToTransmit).toList()
    );
    
    // Remove transmitted bytes from buffer
    _transmissionBuffer.removeRange(0, bytesToTransmit);
    
    // Simulate realistic transmission (parse as if received over serial)
    _parser?.parse(dataToTransmit);
    
    // Also emit raw data for debugging/monitoring
    _rawDataController.add(dataToTransmit);
  }

  /// Get transmission statistics
  Map<String, dynamic> getTransmissionStats() {
    return {
      'isConnected': _isConnected,
      'isPaused': _isPaused,
      'baudRate': _baudRate,
      'bufferSize': _transmissionBuffer.length,
      'systemId': _systemId,
      'componentId': _componentId,
    };
  }

  void dispose() {
    stopSpoofing();
    _frameController.close();
    _rawDataController.close();
    disposeStreams();
    _isInitialized = false;
  }
  
  /// Reset service state without disposing (for settings changes)
  void reset() {
    stopSpoofing();
    _transmissionBuffer.clear();
    _isConnected = false;
    _isPaused = false;
    // Don't reset _isInitialized - keep the stream listeners
  }

  // For testing - reset singleton instance
  static void resetInstanceForTesting() {
    _instance?.dispose();
    _instance = null;
  }
}