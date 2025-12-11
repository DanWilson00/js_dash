/// MAVLink frame builder for creating outgoing packets.
///
/// This is used by the spoof source to generate valid MAVLink frames
/// for testing purposes.
library;

import 'dart:typed_data';

import '../metadata/mavlink_metadata.dart';
import '../metadata/metadata_registry.dart';
import 'mavlink_crc.dart';
import 'mavlink_frame.dart';

/// Builds MAVLink v2 frames from field values.
class MavlinkFrameBuilder {
  final MavlinkMetadataRegistry _registry;

  MavlinkFrameBuilder(this._registry);

  /// Build a MAVLink v2 frame from message name and field values.
  ///
  /// Returns null if the message is unknown.
  Uint8List? buildFrame({
    required String messageName,
    required Map<String, dynamic> values,
    required int sequence,
    required int systemId,
    required int componentId,
  }) {
    final metadata = _registry.getMessageByName(messageName);
    if (metadata == null) return null;

    // Encode payload
    final payload = _encodePayload(metadata, values);

    // Build v2 frame
    return _buildV2Frame(
      sequence: sequence,
      systemId: systemId,
      componentId: componentId,
      messageId: metadata.id,
      payload: payload,
      crcExtra: metadata.crcExtra,
    );
  }

  /// Build a MAVLink v2 frame from message ID and field values.
  Uint8List? buildFrameById({
    required int messageId,
    required Map<String, dynamic> values,
    required int sequence,
    required int systemId,
    required int componentId,
  }) {
    final metadata = _registry.getMessageById(messageId);
    if (metadata == null) return null;

    final payload = _encodePayload(metadata, values);

    return _buildV2Frame(
      sequence: sequence,
      systemId: systemId,
      componentId: componentId,
      messageId: messageId,
      payload: payload,
      crcExtra: metadata.crcExtra,
    );
  }

  /// Encode field values into a payload byte array.
  Uint8List _encodePayload(
    MavlinkMessageMetadata metadata,
    Map<String, dynamic> values,
  ) {
    final payload = Uint8List(metadata.encodedLength);
    final data = ByteData.sublistView(payload);

    for (final field in metadata.fields) {
      if (field.extension) continue; // Skip extension fields for now

      final value = values[field.name];
      if (value == null) continue;

      _encodeField(data, field, value);
    }

    return payload;
  }

  /// Encode a single field value.
  void _encodeField(
    ByteData data,
    MavlinkFieldMetadata field,
    dynamic value,
  ) {
    if (field.isArray && field.baseType == 'char') {
      // String field
      _encodeString(data, field, value.toString());
      return;
    }

    if (field.isArray) {
      // Array of values
      if (value is List) {
        for (int i = 0; i < value.length && i < field.arrayLength; i++) {
          final offset = field.offset + (i * field.size);
          _encodeScalar(data, offset, field.baseType, value[i]);
        }
      }
      return;
    }

    // Scalar value
    _encodeScalar(data, field.offset, field.baseType, value);
  }

  void _encodeScalar(ByteData data, int offset, String type, dynamic value) {
    switch (type) {
      case 'int8_t':
        data.setInt8(offset, (value as num).toInt());
      case 'uint8_t':
        data.setUint8(offset, (value as num).toInt());
      case 'char':
        data.setUint8(offset, (value as num).toInt());
      case 'int16_t':
        data.setInt16(offset, (value as num).toInt(), Endian.little);
      case 'uint16_t':
        data.setUint16(offset, (value as num).toInt(), Endian.little);
      case 'int32_t':
        data.setInt32(offset, (value as num).toInt(), Endian.little);
      case 'uint32_t':
        data.setUint32(offset, (value as num).toInt(), Endian.little);
      case 'int64_t':
        data.setInt64(offset, (value as num).toInt(), Endian.little);
      case 'uint64_t':
        data.setUint64(offset, (value as num).toInt(), Endian.little);
      case 'float':
        data.setFloat32(offset, (value as num).toDouble(), Endian.little);
      case 'double':
        data.setFloat64(offset, (value as num).toDouble(), Endian.little);
    }
  }

  void _encodeString(ByteData data, MavlinkFieldMetadata field, String value) {
    for (int i = 0; i < field.arrayLength; i++) {
      if (i < value.length) {
        data.setUint8(field.offset + i, value.codeUnitAt(i));
      } else {
        data.setUint8(field.offset + i, 0); // Null padding
      }
    }
  }

  /// Build a complete MAVLink v2 frame.
  Uint8List _buildV2Frame({
    required int sequence,
    required int systemId,
    required int componentId,
    required int messageId,
    required Uint8List payload,
    required int crcExtra,
  }) {
    // Header: len, incompat, compat, seq, sysid, compid, msgid(3 bytes)
    final headerBytes = [
      payload.length, // len
      0, // incompat flags
      0, // compat flags
      sequence & 0xFF, // seq
      systemId & 0xFF, // sysid
      componentId & 0xFF, // compid
      messageId & 0xFF, // msgid low
      (messageId >> 8) & 0xFF, // msgid mid
      (messageId >> 16) & 0xFF, // msgid high
    ];

    // Calculate CRC
    final crc = calculateFrameCrc(headerBytes, payload.toList(), crcExtra);

    // Build complete frame
    final frame = Uint8List(1 + headerBytes.length + payload.length + 2);
    frame[0] = MavlinkConstants.stxV2;

    for (int i = 0; i < headerBytes.length; i++) {
      frame[1 + i] = headerBytes[i];
    }

    for (int i = 0; i < payload.length; i++) {
      frame[1 + headerBytes.length + i] = payload[i];
    }

    frame[frame.length - 2] = crc & 0xFF;
    frame[frame.length - 1] = (crc >> 8) & 0xFF;

    return frame;
  }
}
