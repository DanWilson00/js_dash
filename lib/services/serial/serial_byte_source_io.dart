// Desktop implementation of serial byte source
// Uses flutter_libserialport for native serial port access

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import '../../interfaces/i_byte_source.dart';
import 'serial_port_info.dart';

/// Serial port implementation of IByteSource for desktop platforms
/// Reads raw bytes from a serial port for MAVLink parsing
class SerialByteSource implements IByteSource {
  final String portName;
  final int baudRate;

  SerialPort? _serialPort;
  Timer? _serialReader;
  final StreamController<Uint8List> _bytesController =
      StreamController<Uint8List>.broadcast();

  bool _isConnected = false;

  SerialByteSource({
    required this.portName,
    required this.baudRate,
  });

  @override
  Stream<Uint8List> get bytes => _bytesController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> connect() async {
    await disconnect();

    _serialPort = SerialPort(portName);
    if (!_serialPort!.openReadWrite()) {
      throw Exception('Failed to open serial port $portName');
    }

    final serialConfig = _serialPort!.config;
    serialConfig.baudRate = baudRate;
    serialConfig.parity = SerialPortParity.none;
    serialConfig.bits = 8;
    serialConfig.stopBits = 1;
    serialConfig.rts = SerialPortRts.off;
    serialConfig.dtr = SerialPortDtr.off;
    serialConfig.xonXoff = SerialPortXonXoff.disabled;
    _serialPort!.config = serialConfig;

    // Poll for data at 10ms intervals
    _serialReader = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      if (_serialPort != null && _serialPort!.isOpen) {
        try {
          if (_serialPort!.bytesAvailable > 0) {
            final data = _serialPort!.read(_serialPort!.bytesAvailable);
            if (!_bytesController.isClosed) {
              _bytesController.add(data);
            }
          }
        } catch (e) {
          // Ignore read errors - will retry on next poll
        }
      }
    });

    _isConnected = true;
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

    _isConnected = false;
  }

  @override
  void dispose() {
    disconnect();
    _bytesController.close();
  }
}

/// Get list of available serial ports (desktop implementation)
List<SerialPortInfo> getAvailableSerialPorts() {
  return SerialPort.availablePorts.map((portName) {
    try {
      final port = SerialPort(portName);
      final info = SerialPortInfo(
        portName: portName,
        description: port.description,
        vendorId: port.vendorId,
        productId: port.productId,
        serialNumber: port.serialNumber,
      );
      port.dispose();
      return info;
    } catch (e) {
      return SerialPortInfo(portName: portName);
    }
  }).toList();
}

/// Check if serial is supported on this platform
bool get isSerialSupported => true;

/// Request a serial port from the user (no-op on desktop, returns null)
/// On desktop, ports are enumerated via getAvailableSerialPorts()
Future<SerialPortInfo?> requestSerialPort({int? vendorId, int? productId}) async {
  // Desktop doesn't need user permission - ports are directly enumerable
  return null;
}

/// Create a web serial byte source (not available on desktop)
IByteSource createWebSerialByteSource({required int baudRate}) {
  throw UnsupportedError('Web Serial is not supported on desktop platforms');
}
