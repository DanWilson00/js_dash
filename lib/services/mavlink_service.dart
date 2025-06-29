import 'dart:async';
import 'dart:io';
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/common.dart';

class MavlinkService {
  static MavlinkService? _instance;
  factory MavlinkService() => _instance ??= MavlinkService._internal();
  MavlinkService._internal() : _dialect = MavlinkDialectCommon();
  
  // For testing - allows creating fresh instances
  MavlinkService.forTesting() : _dialect = MavlinkDialectCommon();

  final MavlinkDialectCommon _dialect;
  MavlinkParser? _parser;
  
  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _socketSubscription;
  
  final StreamController<MavlinkFrame> _frameController = StreamController<MavlinkFrame>.broadcast();
  final StreamController<Heartbeat> _heartbeatController = StreamController<Heartbeat>.broadcast();
  final StreamController<SysStatus> _sysStatusController = StreamController<SysStatus>.broadcast();
  final StreamController<Attitude> _attitudeController = StreamController<Attitude>.broadcast();
  final StreamController<GlobalPositionInt> _gpsController = StreamController<GlobalPositionInt>.broadcast();
  final StreamController<VfrHud> _vfrHudController = StreamController<VfrHud>.broadcast();

  Stream<MavlinkFrame> get frameStream => _frameController.stream;
  Stream<Heartbeat> get heartbeatStream => _heartbeatController.stream;
  Stream<SysStatus> get sysStatusStream => _sysStatusController.stream;
  Stream<Attitude> get attitudeStream => _attitudeController.stream;
  Stream<GlobalPositionInt> get gpsStream => _gpsController.stream;
  Stream<VfrHud> get vfrHudStream => _vfrHudController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isInitialized = false;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _parser ??= MavlinkParser(_dialect);
    
    _parser!.stream.listen((MavlinkFrame frame) {
      _frameController.add(frame);
      _distributeMessage(frame.message);
    });
    
    _isInitialized = true;
  }

  Future<void> connectUDP({String host = '127.0.0.1', int port = 14550}) async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
      _isConnected = true;
      
      _socketSubscription = _socket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? datagram = _socket!.receive();
          if (datagram != null) {
            _parser?.parse(datagram.data);
          }
        }
      });
      
      // TODO: Replace with proper logging framework
      // print('MAVLink service connected on UDP $host:$port');
    } catch (e) {
      // TODO: Replace with proper logging framework
      // print('Failed to connect MAVLink UDP: $e');
      _isConnected = false;
      rethrow;
    }
  }

  void _distributeMessage(MavlinkMessage message) {
    if (message is Heartbeat) {
      _heartbeatController.add(message);
    } else if (message is SysStatus) {
      _sysStatusController.add(message);
    } else if (message is Attitude) {
      _attitudeController.add(message);
    } else if (message is GlobalPositionInt) {
      _gpsController.add(message);
    } else if (message is VfrHud) {
      _vfrHudController.add(message);
    }
  }

  Future<void> disconnect() async {
    await _socketSubscription?.cancel();
    _socket?.close();
    _isConnected = false;
    // TODO: Replace with proper logging framework
    // print('MAVLink service disconnected');
  }

  void dispose() {
    disconnect();
    _frameController.close();
    _heartbeatController.close();
    _sysStatusController.close();
    _attitudeController.close();
    _gpsController.close();
    _vfrHudController.close();
    _isInitialized = false;
  }

  // For testing - reset singleton instance
  static void resetInstanceForTesting() {
    _instance?.dispose();
    _instance = null;
  }
}