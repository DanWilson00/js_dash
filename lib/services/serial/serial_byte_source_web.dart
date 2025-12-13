// Web implementation of serial services
// Native serial is not available on web, but Web Serial API is

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import '../../interfaces/i_byte_source.dart';
import 'serial_port_info.dart';

// Web Serial API bindings using dart:js_interop

@JS('navigator.serial')
external JSObject? get _navigatorSerial;

extension type _Serial._(JSObject _) implements JSObject {
  external JSPromise<JSArray<JSObject>> getPorts();
  external JSPromise<JSObject> requestPort([JSObject? options]);
}

extension type _SerialPort._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> open(JSObject options);
  external JSPromise<JSAny?> close();
  external JSObject? get readable;
  external JSObject? get writable;
  external JSObject getInfo();
}

extension type _SerialPortInfo._(JSObject _) implements JSObject {
  external int? get usbVendorId;
  external int? get usbProductId;
}

extension type _ReadableStream._(JSObject _) implements JSObject {
  external JSObject getReader();
}

extension type _ReadableStreamReader._(JSObject _) implements JSObject {
  external JSPromise<JSObject> read();
  external void releaseLock();
}

extension type _ReadResult._(JSObject _) implements JSObject {
  external bool get done;
  external JSUint8Array? get value;
}

// Store the requested port for later use
JSObject? _requestedPort;

/// Native serial byte source - NOT available on web
/// Use WebSerialByteSource via requestSerialPort() instead
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
    throw UnsupportedError(
      'Native serial ports are not available in web browsers. '
      'Use Web Serial API via requestSerialPort() on supported browsers (Chrome/Edge).',
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  void dispose() {
    _bytesController.close();
  }
}

/// Web Serial implementation of IByteSource
/// Uses Web Serial API available in Chrome and Edge browsers
class WebSerialByteSource implements IByteSource {
  final int baudRate;

  _SerialPort? _port;
  _ReadableStreamReader? _reader;
  final StreamController<Uint8List> _bytesController =
      StreamController<Uint8List>.broadcast();
  bool _isConnected = false;
  bool _isReading = false;

  WebSerialByteSource({
    required this.baudRate,
  });

  @override
  Stream<Uint8List> get bytes => _bytesController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> connect() async {
    await disconnect();

    final serial = _navigatorSerial;
    if (serial == null) {
      throw Exception('Web Serial API is not available in this browser');
    }

    try {
      // Use pre-requested port if available
      final portObj = _requestedPort;
      _requestedPort = null;

      if (portObj == null) {
        throw Exception(
          'No serial port selected. Call requestSerialPort() first to request user permission.',
        );
      }

      _port = _SerialPort._(portObj);

      // Open the port with specified baud rate
      final options = {'baudRate': baudRate}.jsify()! as JSObject;
      await _port!.open(options).toDart;

      _isConnected = true;

      // Start reading data
      _startReading();
    } catch (e) {
      _isConnected = false;
      _port = null;
      rethrow;
    }
  }

  void _startReading() async {
    if (_isReading) return;
    _isReading = true;

    final readable = _port?.readable;
    if (readable == null) {
      _isReading = false;
      return;
    }

    final stream = _ReadableStream._(readable);
    _reader = _ReadableStreamReader._(stream.getReader());

    try {
      while (_isConnected && _reader != null) {
        final resultObj = await _reader!.read().toDart;
        final result = _ReadResult._(resultObj);

        if (result.done) break;

        final value = result.value;
        if (value != null && !_bytesController.isClosed) {
          _bytesController.add(value.toDart);
        }
      }
    } catch (e) {
      // Reading stopped (probably disconnected)
    } finally {
      _isReading = false;
    }
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;

    if (_reader != null) {
      try {
        _reader!.releaseLock();
      } catch (e) {
        // Ignore release errors
      }
      _reader = null;
    }

    if (_port != null) {
      try {
        await _port!.close().toDart;
      } catch (e) {
        // Ignore close errors
      }
      _port = null;
    }
  }

  @override
  void dispose() {
    disconnect();
    _bytesController.close();
  }
}

/// Get available serial ports (returns empty on web - use requestSerialPort instead)
List<SerialPortInfo> getAvailableSerialPorts() => [];

/// Check if Web Serial API is supported in this browser
bool get isSerialSupported => _navigatorSerial != null;

/// Request a serial port from the user (shows browser permission dialog)
/// Returns a SerialPortInfo if user selects a port, null if cancelled
/// The selected port is stored for use by WebSerialByteSource
Future<SerialPortInfo?> requestSerialPort({int? vendorId, int? productId}) async {
  final serial = _navigatorSerial;
  if (serial == null) return null;

  try {
    final serialApi = _Serial._(serial);

    JSObject? options;
    if (vendorId != null || productId != null) {
      final filter = <String, dynamic>{};
      if (vendorId != null) filter['usbVendorId'] = vendorId;
      if (productId != null) filter['usbProductId'] = productId;
      options = {'filters': [filter]}.jsify() as JSObject?;
    }

    final portObj = await serialApi.requestPort(options).toDart;
    _requestedPort = portObj;  // Store for later use

    final port = _SerialPort._(portObj);
    final info = _SerialPortInfo._(port.getInfo());

    return SerialPortInfo(
      portName: 'Web Serial Port',
      vendorId: info.usbVendorId,
      productId: info.usbProductId,
    );
  } catch (e) {
    // User cancelled or error occurred
    return null;
  }
}

/// Create a WebSerialByteSource for use with a previously requested port
IByteSource createWebSerialByteSource({required int baudRate}) {
  return WebSerialByteSource(baudRate: baudRate);
}
