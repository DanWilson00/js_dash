import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../interfaces/disposable.dart';
import '../interfaces/i_byte_source.dart';
import '../mavlink/mavlink.dart';
import 'generic_message_tracker.dart';

/// Generic MAVLink data provider using the new metadata-driven parser.
///
/// This replaces the hardcoded MavlinkDataProvider with a fully dynamic
/// implementation that uses JSON metadata for message parsing.
class GenericMavlinkProvider implements Disposable {
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

  GenericMavlinkProvider({
    required IByteSource byteSource,
    required MavlinkMetadataRegistry registry,
    required GenericMessageTracker tracker,
  })  : _byteSource = byteSource,
        _registry = registry,
        _tracker = tracker {
    _parser = MavlinkFrameParser(_registry);
    _decoder = MavlinkMessageDecoder(_registry);
  }

  /// Stream of all decoded messages.
  Stream<MavlinkMessage> get messageStream => _messageController.stream;

  /// Stream of raw bytes for debugging.
  Stream<Uint8List> get rawDataStream => _rawDataController.stream;

  /// Stream of message statistics.
  Stream<Map<String, GenericMessageStats>> get statsStream =>
      _tracker.statsStream;

  /// Whether connected to the byte source.
  bool get isConnected => _byteSource.isConnected;

  /// The metadata registry.
  MavlinkMetadataRegistry get registry => _registry;

  /// Get a filtered stream for a specific message name.
  Stream<MavlinkMessage> streamByName(String name) {
    return _messageController.stream.where((msg) => msg.name == name);
  }

  /// Get a filtered stream for a specific message ID.
  Stream<MavlinkMessage> streamById(int id) {
    return _messageController.stream.where((msg) => msg.id == id);
  }

  /// Initialize the provider.
  Future<void> initialize() async {
    // Set up frame processing
    _frameSubscription = _parser.stream.listen((frame) {
      final message = _decoder.decode(frame);
      if (message != null) {
        _tracker.trackMessage(message);
        _messageController.add(message);
      }
    });
  }

  /// Connect to the byte source and start parsing.
  Future<void> connect() async {
    await disconnect();

    // Subscribe to byte stream
    _bytesSubscription = _byteSource.bytes.listen((data) {
      _rawDataController.add(data);
      _parser.parse(data);
    });

    // Connect the byte source
    await _byteSource.connect();
  }

  /// Disconnect from the byte source.
  Future<void> disconnect() async {
    await _bytesSubscription?.cancel();
    _bytesSubscription = null;
    await _byteSource.disconnect();
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
}
