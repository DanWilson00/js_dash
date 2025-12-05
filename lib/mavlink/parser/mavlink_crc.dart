/// MAVLink X.25 CRC implementation.
///
/// This implements the CRC-16-MCRF4XX algorithm used by MAVLink for packet
/// validation. The CRC is calculated over the header, payload, and crc_extra
/// byte to verify packet integrity.
library;

/// X.25 CRC calculator for MAVLink.
class MavlinkCrc {
  int _crc = 0xFFFF;

  /// Current CRC value.
  int get crc => _crc;

  /// Reset CRC to initial value.
  void reset() {
    _crc = 0xFFFF;
  }

  /// Accumulate a single byte into the CRC.
  void accumulate(int byte) {
    byte = byte & 0xFF;
    int tmp = byte ^ (_crc & 0xFF);
    tmp = (tmp ^ ((tmp << 4) & 0xFF)) & 0xFF;
    _crc = ((_crc >> 8) ^ ((tmp << 8) & 0xFFFF) ^ ((tmp << 3) & 0xFFFF) ^ (tmp >> 4)) & 0xFFFF;
  }

  /// Accumulate multiple bytes into the CRC.
  void accumulateBytes(List<int> bytes) {
    for (final byte in bytes) {
      accumulate(byte);
    }
  }

  /// Accumulate a string into the CRC.
  void accumulateString(String s) {
    for (int i = 0; i < s.length; i++) {
      accumulate(s.codeUnitAt(i));
    }
  }

  /// Get the low byte of the CRC.
  int get lowByte => _crc & 0xFF;

  /// Get the high byte of the CRC.
  int get highByte => (_crc >> 8) & 0xFF;

  /// Calculate CRC extra from message name and fields.
  ///
  /// This is used for message identification and is stored in the JSON
  /// metadata, so you typically don't need to call this at runtime.
  static int calculateCrcExtra(String messageName, List<String> fieldTypesAndNames) {
    final crc = MavlinkCrc();
    crc.accumulateString('$messageName ');
    for (final field in fieldTypesAndNames) {
      crc.accumulateString('$field ');
    }
    return (crc.crc & 0xFF) ^ (crc.crc >> 8);
  }
}

/// Convenience function to calculate CRC for a complete MAVLink frame.
///
/// The CRC is calculated over:
/// - Header bytes (excluding STX)
/// - Payload bytes
/// - CRC extra byte (from message definition)
int calculateFrameCrc(List<int> headerBytes, List<int> payloadBytes, int crcExtra) {
  final crc = MavlinkCrc();
  crc.accumulateBytes(headerBytes);
  crc.accumulateBytes(payloadBytes);
  crc.accumulate(crcExtra);
  return crc.crc;
}
