import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/common.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import '../core/connection_config.dart';
import 'mavlink_data_provider.dart';

class MavlinkService extends MavlinkDataProvider {
  // Connection state
  MavlinkParser? _parser;
  RawDatagramSocket? _socket;
  StreamSubscription? _socketSubscription;
  SerialPort? _serialPort;
  Timer? _serialReader;

  final StreamController<MavlinkFrame> _frameController =
      StreamController<MavlinkFrame>.broadcast();
  final StreamController<Uint8List> _rawDataController =
      StreamController<Uint8List>.broadcast();

  // Configuration
  ConnectionConfig? _currentConfig;
  final MavlinkDialect _dialect;

  MavlinkService({required super.tracker}) : _dialect = MavlinkDialectCommon();

  Stream<MavlinkFrame> get frameStream => _frameController.stream;
  Stream<Uint8List> get rawDataStream => _rawDataController.stream;

  // Implement IDataSource.messageStream
  @override
  Stream<dynamic> get messageStream =>
      frameStream.map((frame) => frame.message);

  @override
  bool get isConnected =>
      (_socket != null) || (_serialPort != null && _serialPort!.isOpen);

  @override
  bool get isPaused => _socketSubscription?.isPaused ?? false;

  /// Configure the service with connection settings
  void configure(ConnectionConfig config) {
    _currentConfig = config;
  }

  @override
  Future<void> initialize() async {
    // No initialization needed for now
  }

  @override
  Future<void> connect() async {
    if (_currentConfig == null) {
      throw Exception('Connection configuration not set');
    }

    if (_currentConfig is UdpConnectionConfig) {
      await _connectUdp(_currentConfig as UdpConnectionConfig);
    } else if (_currentConfig is SerialConnectionConfig) {
      await _connectSerial(_currentConfig as SerialConnectionConfig);
    } else {
      throw Exception('Unsupported connection type');
    }
  }

  Future<void> _connectUdp(UdpConnectionConfig config) async {
    await disconnect();

    try {
      _parser = MavlinkParser(_dialect);
      _parser!.stream.listen((MavlinkFrame frame) {
        _frameController.add(frame);
        addMessage(frame.message);
      });

      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket!.broadcastEnabled = true;

      // Send a heartbeat to start the connection
      // TODO: Implement heartbeat sending

      _socketSubscription = _socket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            _rawDataController.add(datagram.data);
            _parser!.parse(datagram.data);
          }
        }
      });
    } catch (e) {
      await disconnect();
      rethrow;
    }
  }

  Future<void> _connectSerial(SerialConnectionConfig config) async {
    await disconnect();

    try {
      _parser = MavlinkParser(_dialect);
      _parser!.stream.listen((MavlinkFrame frame) {
        _frameController.add(frame);
        addMessage(frame.message);
      });

      _serialPort = SerialPort(config.port);
      if (!_serialPort!.openReadWrite()) {
        throw Exception('Failed to open serial port ${config.port}');
      }

      final serialConfig = _serialPort!.config;
      serialConfig.baudRate = config.baudRate;
      serialConfig.parity = SerialPortParity.none;
      serialConfig.bits = 8;
      serialConfig.stopBits = 1;
      serialConfig.rts = SerialPortRts.off;
      serialConfig.dtr = SerialPortDtr.off;
      serialConfig.xonXoff = SerialPortXonXoff.disabled;
      _serialPort!.config = serialConfig;

      // Poll for data
      _serialReader = Timer.periodic(const Duration(milliseconds: 10), (timer) {
        if (_serialPort != null && _serialPort!.isOpen) {
          try {
            if (_serialPort!.bytesAvailable > 0) {
              final data = _serialPort!.read(_serialPort!.bytesAvailable);
              _rawDataController.add(data);
              _parser!.parse(data);
            }
          } catch (e) {
            // Ignore read errors
          }
        }
      });
    } catch (e) {
      await disconnect();
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _serialReader?.cancel();
    _serialReader = null;

    if (_serialPort != null) {
      if (_serialPort!.isOpen) _serialPort!.close();
      _serialPort!.dispose();
      _serialPort = null;
    }

    _socketSubscription?.cancel();
    _socketSubscription = null;

    _socket?.close();
    _socket = null;

    _parser = null;
  }

  @override
  void pause() {
    _socketSubscription?.pause();
  }

  @override
  void resume() {
    _socketSubscription?.resume();
  }

  @override
  void dispose() {
    disconnect();
    _frameController.close();
    _rawDataController.close();
    super.dispose();
  }

  /// Get available serial ports
  static List<String> getAvailableSerialPorts() {
    return SerialPort.availablePorts;
  }
}
