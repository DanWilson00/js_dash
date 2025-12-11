/// MAVLink frame parser.
///
/// A state machine parser that processes incoming bytes and emits complete
/// MAVLink frames. Supports both v1 and v2 protocol versions.
library;

import 'dart:async';
import 'dart:typed_data';

import '../metadata/metadata_registry.dart';
import 'mavlink_crc.dart';
import 'mavlink_frame.dart';

/// Parser state machine states.
enum _ParserState {
  waitingForStx,
  readingLength,
  readingIncompatFlags, // v2 only
  readingCompatFlags, // v2 only
  readingSequence,
  readingSystemId,
  readingComponentId,
  readingMessageIdLow,
  readingMessageIdMid, // v2 only
  readingMessageIdHigh, // v2 only
  readingPayload,
  readingCrcLow,
  readingCrcHigh,
}

/// Stream-based MAVLink frame parser.
///
/// Parses incoming byte streams and emits complete [MavlinkFrame] objects.
/// Requires a [MavlinkMetadataRegistry] for CRC validation.
class MavlinkFrameParser {
  final MavlinkMetadataRegistry _registry;

  // Parser state
  _ParserState _state = _ParserState.waitingForStx;
  MavlinkVersion? _version;
  int _payloadLength = 0;
  int _incompatFlags = 0;
  int _compatFlags = 0;
  int _sequence = 0;
  int _systemId = 0;
  int _componentId = 0;
  int _messageId = 0;
  final List<int> _payload = [];
  int _crcLow = 0;
  int _payloadIndex = 0;

  // For CRC calculation
  final List<int> _headerBytes = [];

  // Statistics
  int _framesReceived = 0;
  int _crcErrors = 0;
  int _unknownMessages = 0;

  // Output stream
  final StreamController<MavlinkFrame> _frameController =
      StreamController<MavlinkFrame>.broadcast();

  /// Create a parser with the given metadata registry.
  MavlinkFrameParser(this._registry);

  /// Stream of parsed frames.
  Stream<MavlinkFrame> get stream => _frameController.stream;

  /// Number of frames successfully received.
  int get framesReceived => _framesReceived;

  /// Number of CRC errors encountered.
  int get crcErrors => _crcErrors;

  /// Number of unknown message IDs encountered.
  int get unknownMessages => _unknownMessages;

  /// Parse incoming bytes.
  ///
  /// Can be called with any number of bytes - the parser maintains state
  /// between calls to handle partial frames.
  void parse(Uint8List data) {
    for (final byte in data) {
      _processByte(byte);
    }
  }

  /// Process a single byte through the state machine.
  void _processByte(int byte) {
    switch (_state) {
      case _ParserState.waitingForStx:
        if (byte == MavlinkConstants.stxV1) {
          _version = MavlinkVersion.v1;
          _reset();
          _state = _ParserState.readingLength;
        } else if (byte == MavlinkConstants.stxV2) {
          _version = MavlinkVersion.v2;
          _reset();
          _state = _ParserState.readingLength;
        }

      case _ParserState.readingLength:
        _payloadLength = byte;
        _headerBytes.add(byte);
        if (_version == MavlinkVersion.v2) {
          _state = _ParserState.readingIncompatFlags;
        } else {
          _state = _ParserState.readingSequence;
        }

      case _ParserState.readingIncompatFlags:
        _incompatFlags = byte;
        _headerBytes.add(byte);
        _state = _ParserState.readingCompatFlags;

      case _ParserState.readingCompatFlags:
        _compatFlags = byte;
        _headerBytes.add(byte);
        _state = _ParserState.readingSequence;

      case _ParserState.readingSequence:
        _sequence = byte;
        _headerBytes.add(byte);
        _state = _ParserState.readingSystemId;

      case _ParserState.readingSystemId:
        _systemId = byte;
        _headerBytes.add(byte);
        _state = _ParserState.readingComponentId;

      case _ParserState.readingComponentId:
        _componentId = byte;
        _headerBytes.add(byte);
        _state = _ParserState.readingMessageIdLow;

      case _ParserState.readingMessageIdLow:
        _messageId = byte;
        _headerBytes.add(byte);
        if (_version == MavlinkVersion.v2) {
          _state = _ParserState.readingMessageIdMid;
        } else {
          _state = _payloadLength > 0
              ? _ParserState.readingPayload
              : _ParserState.readingCrcLow;
        }

      case _ParserState.readingMessageIdMid:
        _messageId |= (byte << 8);
        _headerBytes.add(byte);
        _state = _ParserState.readingMessageIdHigh;

      case _ParserState.readingMessageIdHigh:
        _messageId |= (byte << 16);
        _headerBytes.add(byte);
        _state = _payloadLength > 0
            ? _ParserState.readingPayload
            : _ParserState.readingCrcLow;

      case _ParserState.readingPayload:
        _payload.add(byte);
        _payloadIndex++;
        if (_payloadIndex >= _payloadLength) {
          _state = _ParserState.readingCrcLow;
        }

      case _ParserState.readingCrcLow:
        _crcLow = byte;
        _state = _ParserState.readingCrcHigh;

      case _ParserState.readingCrcHigh:
        final crcHigh = byte;
        final receivedCrc = _crcLow | (crcHigh << 8);
        _emitFrame(receivedCrc);
        _state = _ParserState.waitingForStx;
    }
  }

  /// Emit a complete frame.
  void _emitFrame(int receivedCrc) {
    // Look up CRC extra from metadata
    final msgMeta = _registry.getMessageById(_messageId);
    if (msgMeta == null) {
      _unknownMessages++;
      _state = _ParserState.waitingForStx;
      return;
    }

    // Calculate expected CRC
    final calculatedCrc = calculateFrameCrc(
      _headerBytes,
      _payload,
      msgMeta.crcExtra,
    );

    final frame = MavlinkFrame(
      version: _version!,
      payloadLength: _payloadLength,
      incompatFlags: _incompatFlags,
      compatFlags: _compatFlags,
      sequence: _sequence,
      systemId: _systemId,
      componentId: _componentId,
      messageId: _messageId,
      payload: Uint8List.fromList(_payload),
      receivedCrc: receivedCrc,
      calculatedCrc: calculatedCrc,
    );

    if (frame.crcValid) {
      _framesReceived++;
      _frameController.add(frame);
    } else {
      _crcErrors++;
    }
  }

  /// Reset parser state for a new frame.
  void _reset() {
    _payloadLength = 0;
    _incompatFlags = 0;
    _compatFlags = 0;
    _sequence = 0;
    _systemId = 0;
    _componentId = 0;
    _messageId = 0;
    _payload.clear();
    _crcLow = 0;
    _payloadIndex = 0;
    _headerBytes.clear();
  }

  /// Dispose the parser and close the stream.
  void dispose() {
    _frameController.close();
  }
}
