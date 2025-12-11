import 'dart:async';
import 'dart:typed_data';

import '../interfaces/i_byte_source.dart';
import '../interfaces/i_data_source.dart';
import '../mavlink/mavlink.dart';
import 'generic_message_tracker.dart';
import 'serial_byte_source.dart';

/// MAVLink service that parses bytes from an IByteSource
/// This service handles the MAVLink protocol parsing and message dispatch
class MavlinkService implements IDataSource {
  final IByteSource _byteSource;
  final MavlinkMetadataRegistry _registry;
  final GenericMessageTracker _tracker;

  late final MavlinkFrameParser _parser;
  late final MavlinkMessageDecoder _decoder;

  StreamSubscription<Uint8List>? _bytesSubscription;
  StreamSubscription<MavlinkFrame>? _frameSubscription;

  final StreamController<MavlinkMessage> _messageController =
      StreamController<MavlinkMessage>.broadcast();
  final StreamController<Uint8List> _rawDataController =
      StreamController<Uint8List>.broadcast();

  bool _isPaused = false;

  MavlinkService({
    required IByteSource byteSource,
    required MavlinkMetadataRegistry registry,
    required GenericMessageTracker tracker,
  })  : _byteSource = byteSource,
        _registry = registry,
        _tracker = tracker {
    _parser = MavlinkFrameParser(_registry);
    _decoder = MavlinkMessageDecoder(_registry);
  }

  @override
  Stream<MavlinkMessage> get messageStream => _messageController.stream;

  Stream<Uint8List> get rawDataStream => _rawDataController.stream;

  Stream<Map<String, GenericMessageStats>> get messageStatsStream =>
      _tracker.statsStream;

  @override
  Stream<MavlinkMessage> streamByName(String name) {
    return _messageController.stream.where((msg) => msg.name == name);
  }

  @override
  Stream<MavlinkMessage> streamById(int id) {
    return _messageController.stream.where((msg) => msg.id == id);
  }

  @override
  bool get isConnected => _byteSource.isConnected;

  @override
  bool get isPaused => _isPaused;

  /// The metadata registry.
  MavlinkMetadataRegistry get registry => _registry;

  @override
  Future<void> initialize() async {
    // Set up frame processing
    _frameSubscription = _parser.stream.listen((frame) {
      final message = _decoder.decode(frame);
      if (message != null) {
        _tracker.trackMessage(message);
        if (!_isPaused) {
          _messageController.add(message);
        }
      }
    });
  }

  @override
  Future<void> connect() async {
    await disconnect();

    // Ensure parser is initialized
    if (_frameSubscription == null) {
      await initialize();
    }

    // Subscribe to byte stream
    _bytesSubscription = _byteSource.bytes.listen((data) {
      _rawDataController.add(data);
      _parser.parse(data);
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
    _isPaused = true;
  }

  @override
  void resume() {
    _isPaused = false;
  }

  @override
  void dispose() {
    disconnect();
    _frameSubscription?.cancel();
    _byteSource.dispose();
    _parser.dispose();
    _messageController.close();
    _rawDataController.close();
  }

  /// Get available serial ports (convenience method)
  static List<String> getAvailableSerialPorts() {
    return SerialByteSource.getAvailablePorts();
  }
}
