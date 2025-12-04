import 'dart:async';
import 'dart:typed_data';
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/common.dart';
import '../interfaces/i_byte_source.dart';
import 'mavlink_data_provider.dart';
import 'serial_byte_source.dart';

/// MAVLink service that parses bytes from an IByteSource
/// This service handles the MAVLink protocol parsing and message dispatch
class MavlinkService extends MavlinkDataProvider {
  final IByteSource _byteSource;
  final MavlinkDialect _dialect;

  MavlinkParser? _parser;
  StreamSubscription<Uint8List>? _bytesSubscription;

  final StreamController<MavlinkFrame> _frameController =
      StreamController<MavlinkFrame>.broadcast();
  final StreamController<Uint8List> _rawDataController =
      StreamController<Uint8List>.broadcast();

  MavlinkService({
    required IByteSource byteSource,
    required super.tracker,
  })  : _byteSource = byteSource,
        _dialect = MavlinkDialectCommon();

  Stream<MavlinkFrame> get frameStream => _frameController.stream;
  Stream<Uint8List> get rawDataStream => _rawDataController.stream;

  @override
  Stream<dynamic> get messageStream =>
      frameStream.map((frame) => frame.message);

  @override
  bool get isConnected => _byteSource.isConnected;

  @override
  bool get isPaused => false; // Pause handled at byte source level

  @override
  Future<void> initialize() async {
    _parser = MavlinkParser(_dialect);
    _parser!.stream.listen((MavlinkFrame frame) {
      _frameController.add(frame);
      addMessage(frame.message);
    });
  }

  @override
  Future<void> connect() async {
    await disconnect();

    // Ensure parser is initialized
    if (_parser == null) {
      await initialize();
    }

    // Subscribe to byte stream
    _bytesSubscription = _byteSource.bytes.listen((data) {
      _rawDataController.add(data);
      _parser?.parse(data);
    });

    // Connect the byte source
    await _byteSource.connect();
  }

  @override
  Future<void> disconnect() async {
    await _bytesSubscription?.cancel();
    _bytesSubscription = null;
    await _byteSource.disconnect();
  }

  @override
  void pause() {
    // Could implement pause at byte source level if needed
  }

  @override
  void resume() {
    // Could implement resume at byte source level if needed
  }

  @override
  void dispose() {
    disconnect();
    _byteSource.dispose();
    _frameController.close();
    _rawDataController.close();
    super.dispose();
  }

  /// Get available serial ports (convenience method)
  static List<String> getAvailableSerialPorts() {
    return SerialByteSource.getAvailablePorts();
  }
}
