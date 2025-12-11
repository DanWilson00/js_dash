/// MAVLink frame structure.
///
/// A MAVLink frame represents a complete parsed packet, including header
/// information and the decoded payload.
library;

import 'dart:typed_data';

/// MAVLink protocol version.
enum MavlinkVersion {
  /// MAVLink 1.0 (STX = 0xFE)
  v1,

  /// MAVLink 2.0 (STX = 0xFD)
  v2,
}

/// Represents a complete MAVLink frame.
class MavlinkFrame {
  /// Protocol version (v1 or v2).
  final MavlinkVersion version;

  /// Payload length in bytes.
  final int payloadLength;

  /// Incompatibility flags (v2 only, 0 for v1).
  final int incompatFlags;

  /// Compatibility flags (v2 only, 0 for v1).
  final int compatFlags;

  /// Packet sequence number (0-255).
  final int sequence;

  /// System ID of the sender.
  final int systemId;

  /// Component ID of the sender.
  final int componentId;

  /// Message ID.
  final int messageId;

  /// Raw payload bytes.
  final Uint8List payload;

  /// Received CRC (low byte, high byte).
  final int receivedCrc;

  /// Calculated CRC for validation.
  final int calculatedCrc;

  /// Whether the CRC is valid.
  bool get crcValid => receivedCrc == calculatedCrc;

  /// Whether this is a signed packet (v2 only).
  bool get isSigned => version == MavlinkVersion.v2 && (incompatFlags & 0x01) != 0;

  const MavlinkFrame({
    required this.version,
    required this.payloadLength,
    required this.incompatFlags,
    required this.compatFlags,
    required this.sequence,
    required this.systemId,
    required this.componentId,
    required this.messageId,
    required this.payload,
    required this.receivedCrc,
    required this.calculatedCrc,
  });

  @override
  String toString() {
    return 'MavlinkFrame('
        'v${version == MavlinkVersion.v1 ? "1" : "2"}, '
        'msgId=$messageId, '
        'sysId=$systemId, '
        'compId=$componentId, '
        'seq=$sequence, '
        'len=$payloadLength, '
        'crc=${crcValid ? "OK" : "BAD"})';
  }
}

/// MAVLink protocol constants.
class MavlinkConstants {
  /// MAVLink v1 start byte.
  static const int stxV1 = 0xFE;

  /// MAVLink v2 start byte.
  static const int stxV2 = 0xFD;

  /// MAVLink v1 header length (excluding STX).
  static const int headerLengthV1 = 5;

  /// MAVLink v2 header length (excluding STX).
  static const int headerLengthV2 = 9;

  /// CRC length (2 bytes).
  static const int crcLength = 2;

  /// Signature length for signed packets.
  static const int signatureLength = 13;

  /// Maximum payload length for v1.
  static const int maxPayloadLengthV1 = 255;

  /// Maximum payload length for v2.
  static const int maxPayloadLengthV2 = 255;
}
