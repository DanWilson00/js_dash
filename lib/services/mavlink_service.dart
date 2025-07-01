import 'dart:async';
import 'dart:io';
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/common.dart';
import 'mavlink_data_provider.dart';

class MavlinkService extends MavlinkDataProvider {
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

  Stream<MavlinkFrame> get frameStream => _frameController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isInitialized = false;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _parser ??= MavlinkParser(_dialect);
    
    _parser!.stream.listen((MavlinkFrame frame) {
      _frameController.add(frame);
      addMessage(frame.message);
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
    disposeStreams();
    _isInitialized = false;
  }

  // For testing - reset singleton instance
  static void resetInstanceForTesting() {
    _instance?.dispose();
    _instance = null;
  }
}