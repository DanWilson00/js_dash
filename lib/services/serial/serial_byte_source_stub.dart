// Stub implementation of serial byte source
// Used when neither desktop nor web serial is available

import 'dart:async';
import 'dart:typed_data';
import '../../interfaces/i_byte_source.dart';
import 'serial_port_info.dart';

/// Stub serial byte source that always fails
/// Used on platforms without serial support
class SerialByteSource implements IByteSource {
  final String portName;
  final int baudRate;

  final StreamController<Uint8List> _bytesController =
      StreamController<Uint8List>.broadcast();

  SerialByteSource({
    required this.portName,
    required this.baudRate,
  });

  @override
  Stream<Uint8List> get bytes => _bytesController.stream;

  @override
  bool get isConnected => false;

  @override
  Future<void> connect() async {
    throw UnsupportedError('Serial communication is not supported on this platform');
  }

  @override
  Future<void> disconnect() async {
    // No-op
  }

  @override
  void dispose() {
    _bytesController.close();
  }
}

/// Get available serial ports (stub - always empty)
List<SerialPortInfo> getAvailableSerialPorts() => [];

/// Check if serial is supported (stub - always false)
bool get isSerialSupported => false;

/// Request a serial port (stub - always returns null)
Future<SerialPortInfo?> requestSerialPort({int? vendorId, int? productId}) async => null;

/// Create a web serial byte source (stub - throws)
IByteSource createWebSerialByteSource({required int baudRate}) {
  throw UnsupportedError('Web Serial is not supported on this platform');
}
