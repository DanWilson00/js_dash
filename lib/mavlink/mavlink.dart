/// Custom MAVLink implementation for Flutter.
///
/// This library provides:
/// - Metadata loading from JSON dialect files
/// - Stream-based frame parsing (v1 and v2)
/// - Dynamic message decoding
/// - Enum resolution
///
/// Example usage:
/// ```dart
/// // Load metadata
/// final registry = MavlinkMetadataRegistry();
/// await registry.loadFromFile('assets/common.json');
///
/// // Create parser
/// final parser = MavlinkFrameParser(registry);
/// final decoder = MavlinkMessageDecoder(registry);
///
/// // Listen for messages
/// parser.stream.listen((frame) {
///   final message = decoder.decode(frame);
///   if (message != null) {
///     print('${message.name}: ${message.values}');
///   }
/// });
///
/// // Feed bytes
/// parser.parse(incomingBytes);
/// ```
library;

export 'metadata/mavlink_metadata.dart';
export 'metadata/metadata_registry.dart';
export 'parser/frame_builder.dart';
export 'parser/mavlink_crc.dart';
export 'parser/mavlink_frame.dart';
export 'parser/mavlink_frame_parser.dart';
export 'parser/message_decoder.dart';
