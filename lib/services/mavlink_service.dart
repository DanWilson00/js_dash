import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/common.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'mavlink_data_provider.dart';

class MavlinkService extends MavlinkDataProvider {
  // Singleton support for backward compatibility - will be deprecated
  static MavlinkService? _instance;
  factory MavlinkService() => _instance ??= MavlinkService._internal();
  MavlinkService._internal() : _dialect = MavlinkDialectCommon();
  
  // New constructor for dependency injection
  MavlinkService.injected() : _dialect = MavlinkDialectCommon();
  
  // For testing - allows creating fresh instances
  MavlinkService.forTesting() : _dialect = MavlinkDialectCommon();

  final MavlinkDialectCommon _dialect;
  MavlinkParser? _parser;
  
  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _socketSubscription;
  
  SerialPort? _serialPort;
  StreamSubscription<Uint8List>? _serialSubscription;
  Timer? _serialReader;
  
  final StreamController<MavlinkFrame> _frameController = StreamController<MavlinkFrame>.broadcast();

  Stream<MavlinkFrame> get frameStream => _frameController.stream;
  
  // Implement IDataSource.messageStream
  @override
  Stream<dynamic> get messageStream => frameStream.map((frame) => frame.message);

  bool _isConnected = false;
  @override
  bool get isConnected => _isConnected;
  
  // Implement IDataSource.isPaused
  bool _isPaused = false;
  @override
  bool get isPaused => _isPaused;
  
  // Implement IDataSource.pause/resume
  @override
  void pause() {
    _isPaused = true;
  }
  
  @override
  void resume() {
    _isPaused = false;
  }
  
  // Implement IDataSource.connect (delegates to specific connection methods)
  @override
  Future<void> connect() async {
    // This is a placeholder - actual connection depends on configuration
    // In a real implementation, this would be handled by ConnectionManager
    throw UnimplementedError('Use connectUDP() or connectSerial() instead');
  }

  bool _isInitialized = false;
  
  @override
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

  Future<void> connectSerial({required String portName, int baudRate = 115200}) async {
    try {
      // Disconnect any existing connection first
      await disconnect();
      
      _serialPort = SerialPort(portName);
      
      // Configure serial port settings
      final config = SerialPortConfig();
      config.baudRate = baudRate;
      config.bits = 8;
      config.parity = SerialPortParity.none;
      config.stopBits = 1;
      config.setFlowControl(SerialPortFlowControl.none);
      
      _serialPort!.config = config;
      
      // Open the serial port
      if (!_serialPort!.openReadWrite()) {
        throw Exception('Failed to open serial port: ${SerialPort.lastError}');
      }
      
      _isConnected = true;
      
      // Set up periodic reading from serial port
      _serialReader = Timer.periodic(const Duration(milliseconds: 10), (_) {
        try {
          final buffer = _serialPort!.read(1024); // Read up to 1KB at a time
          if (buffer.isNotEmpty) {
            _parser?.parse(buffer);
          }
        } catch (e) {
          // Handle read errors gracefully
          // TODO: Replace with proper logging framework
          // print('Serial read error: $e');
        }
      });
      
      // TODO: Replace with proper logging framework
      // print('MAVLink service connected on Serial $portName at $baudRate baud');
    } catch (e) {
      // TODO: Replace with proper logging framework
      // print('Failed to connect MAVLink Serial: $e');
      _isConnected = false;
      _serialPort?.close();
      _serialPort = null;
      rethrow;
    }
  }

  /// Get available serial ports
  static List<String> getAvailableSerialPorts() {
    try {
      return SerialPort.availablePorts;
    } catch (e) {
      // TODO: Replace with proper logging framework
      // print('Failed to get available serial ports: $e');
      return [];
    }
  }


  @override
  Future<void> disconnect() async {
    await _socketSubscription?.cancel();
    _socket?.close();
    
    _serialReader?.cancel();
    _serialPort?.close();
    _serialPort = null;
    
    _isConnected = false;
    // TODO: Replace with proper logging framework
    // print('MAVLink service disconnected');
  }

  @override
  void dispose() {
    disconnect();
    _frameController.close();
    super.dispose();
    _isInitialized = false;
  }

  // For testing - reset singleton instance
  static void resetInstanceForTesting() {
    _instance?.dispose();
    _instance = null;
  }
}