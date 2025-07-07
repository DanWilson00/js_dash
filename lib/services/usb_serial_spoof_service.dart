import 'dart:async';
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
  
  Timer? _telemetryTimer;
  Timer? _heartbeatTimer;
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

  Stream<MavlinkFrame> get frameStream => _frameController.stream;
  Stream<Uint8List> get rawDataStream => _rawDataController.stream;
  bool get isConnected => _isConnected;
  bool get isPaused => _isPaused;
  
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
    
    // Start telemetry generation (5 Hz)
    _telemetryTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _generateTelemetryMessages(),
    );
    
    // Start heartbeat generation (1 Hz)
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 1),
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
    _telemetryTimer?.cancel();
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

  /// Generate realistic telemetry messages
  void _generateTelemetryMessages() {
    if (_isPaused || !_isConnected) return;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Simulate realistic vehicle movement
    _altitude += (DateTime.now().millisecond % 100 - 50) / 1000.0;
    _altitude = _altitude.clamp(0.0, 100.0);
    
    _groundSpeed += (DateTime.now().millisecond % 60 - 30) / 100.0;
    _groundSpeed = _groundSpeed.clamp(0.0, 30.0);
    
    _heading += (DateTime.now().millisecond % 20 - 10) / 10.0;
    _heading = _heading % 360.0;
    if (_heading < 0) _heading += 360.0;
    
    _pitch += (DateTime.now().millisecond % 10 - 5) / 100.0;
    _pitch = _pitch.clamp(-30.0, 30.0);
    
    _roll += (DateTime.now().millisecond % 10 - 5) / 100.0;
    _roll = _roll.clamp(-30.0, 30.0);
    
    _yaw = _heading * 3.14159 / 180.0; // Convert to radians
    
    _batteryVoltage = 12.6 + (DateTime.now().millisecond % 100 - 50) / 1000.0;
    _batteryVoltage = _batteryVoltage.clamp(10.0, 13.0);
    
    // Generate GLOBAL_POSITION_INT message
    final globalPosMsg = GlobalPositionInt(
      timeBootMs: now,
      lat: 340000000, // 34.0 degrees in 1E7 format
      lon: -1180000000, // -118.0 degrees in 1E7 format
      alt: (_altitude * 1000).round(),
      relativeAlt: (_altitude * 1000).round(),
      vx: (_groundSpeed * 100).round(),
      vy: 0,
      vz: 0,
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
    
    // Queue messages for transmission
    _queueMessageForTransmission(globalPosMsg);
    _queueMessageForTransmission(attitudeMsg);
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