/// MAVLink message decoder.
///
/// Decodes raw payload bytes into field values using metadata.
/// All multi-byte reads use little-endian byte order per MAVLink spec.
library;

import 'dart:typed_data';

import '../metadata/mavlink_metadata.dart';
import '../metadata/metadata_registry.dart';
import 'mavlink_frame.dart';

/// A decoded MAVLink message with field values.
class MavlinkMessage {
  /// Message ID.
  final int id;

  /// Message name (e.g., "HEARTBEAT").
  final String name;

  /// Message metadata.
  final MavlinkMessageMetadata metadata;

  /// Decoded field values keyed by field name.
  final Map<String, dynamic> values;

  /// Source frame information.
  final int systemId;
  final int componentId;
  final int sequence;

  const MavlinkMessage({
    required this.id,
    required this.name,
    required this.metadata,
    required this.values,
    required this.systemId,
    required this.componentId,
    required this.sequence,
  });

  /// Get a field value by name.
  dynamic operator [](String fieldName) => values[fieldName];

  /// Check if a field exists.
  bool hasField(String fieldName) => values.containsKey(fieldName);

  /// Get a field value as a specific type.
  T? getAs<T>(String fieldName) {
    final value = values[fieldName];
    if (value is T) return value;
    return null;
  }

  @override
  String toString() {
    return 'MavlinkMessage($name, id=$id, values=$values)';
  }
}

/// Decodes MAVLink frame payloads into [MavlinkMessage] objects.
class MavlinkMessageDecoder {
  final MavlinkMetadataRegistry _registry;

  MavlinkMessageDecoder(this._registry);

  /// Decode a frame into a message.
  ///
  /// Returns null if the message ID is unknown.
  MavlinkMessage? decode(MavlinkFrame frame) {
    final metadata = _registry.getMessageById(frame.messageId);
    if (metadata == null) return null;

    final values = decodePayload(frame.payload, metadata);

    return MavlinkMessage(
      id: frame.messageId,
      name: metadata.name,
      metadata: metadata,
      values: values,
      systemId: frame.systemId,
      componentId: frame.componentId,
      sequence: frame.sequence,
    );
  }

  /// Decode raw payload bytes using message metadata.
  Map<String, dynamic> decodePayload(
    Uint8List payload,
    MavlinkMessageMetadata metadata,
  ) {
    // Track original payload length for truncation detection
    final originalLength = payload.length;

    // MAVLink v2 zero-trimming: pad payload with zeros to expected length
    // Senders trim trailing zeros to save bandwidth, receivers must pad them back
    Uint8List paddedPayload;
    if (payload.length < metadata.encodedLength) {
      paddedPayload = Uint8List(metadata.encodedLength);
      paddedPayload.setRange(0, payload.length, payload);
      // Remaining bytes are already zero (Uint8List default)
    } else {
      paddedPayload = payload;
    }

    final values = <String, dynamic>{};
    final data = ByteData.sublistView(paddedPayload);

    for (final field in metadata.fields) {
      // Skip fields that weren't present in the original payload
      // This handles truncated payloads while still allowing MAVLink v2
      // zero-trimming (where trailing zeros are intentionally omitted)
      final fieldEnd = field.offset + (field.isArray ? field.size * field.arrayLength : field.size);
      if (field.offset >= originalLength) continue;

      try {
        final value = _decodeField(data, field, paddedPayload.length);
        values[field.name] = value;
      } catch (e) {
        // Skip fields that can't be decoded (truncated payload)
      }
    }

    return values;
  }

  /// Decode a single field from the payload.
  dynamic _decodeField(
    ByteData data,
    MavlinkFieldMetadata field,
    int payloadLength,
  ) {
    if (field.isArray) {
      return _decodeArrayField(data, field, payloadLength);
    }
    return _decodeScalarField(data, field);
  }

  /// Decode a scalar (non-array) field.
  dynamic _decodeScalarField(ByteData data, MavlinkFieldMetadata field) {
    switch (field.baseType) {
      case 'int8_t':
        return data.getInt8(field.offset);
      case 'uint8_t':
        return data.getUint8(field.offset);
      case 'char':
        return data.getUint8(field.offset);
      case 'int16_t':
        return data.getInt16(field.offset, Endian.little);
      case 'uint16_t':
        return data.getUint16(field.offset, Endian.little);
      case 'int32_t':
        return data.getInt32(field.offset, Endian.little);
      case 'uint32_t':
        return data.getUint32(field.offset, Endian.little);
      case 'int64_t':
        return data.getInt64(field.offset, Endian.little);
      case 'uint64_t':
        return data.getUint64(field.offset, Endian.little);
      case 'float':
        return data.getFloat32(field.offset, Endian.little);
      case 'double':
        return data.getFloat64(field.offset, Endian.little);
      default:
        return data.getUint8(field.offset);
    }
  }

  /// Decode an array field.
  dynamic _decodeArrayField(
    ByteData data,
    MavlinkFieldMetadata field,
    int payloadLength,
  ) {
    // For char arrays, return as string (trimming null terminators)
    if (field.baseType == 'char') {
      return _decodeString(data, field, payloadLength);
    }

    // For other arrays, return as list
    final values = <dynamic>[];
    for (int i = 0; i < field.arrayLength; i++) {
      final offset = field.offset + (i * field.size);
      if (offset + field.size > payloadLength) break;

      final elementField = MavlinkFieldMetadata(
        name: '${field.name}[$i]',
        type: field.baseType,
        baseType: field.baseType,
        offset: offset,
        size: field.size,
        arrayLength: 1,
        description: '',
        extension: field.extension,
      );
      values.add(_decodeScalarField(data, elementField));
    }
    return values;
  }

  /// Decode a char array as a string.
  String _decodeString(
    ByteData data,
    MavlinkFieldMetadata field,
    int payloadLength,
  ) {
    final bytes = <int>[];
    for (int i = 0; i < field.arrayLength; i++) {
      final offset = field.offset + i;
      if (offset >= payloadLength) break;
      final byte = data.getUint8(offset);
      if (byte == 0) break; // Null terminator
      bytes.add(byte);
    }
    return String.fromCharCodes(bytes);
  }
}

/// Convenience function to resolve enum values in a message.
///
/// Returns a new map with enum fields resolved to their string names.
Map<String, dynamic> resolveEnumValues(
  MavlinkMessage message,
  MavlinkMetadataRegistry registry,
) {
  final resolved = <String, dynamic>{};

  for (final entry in message.values.entries) {
    final field = message.metadata.getField(entry.key);
    if (field?.enumType != null && entry.value is int) {
      final enumName = registry.resolveEnumValue(
        field!.enumType!,
        entry.value as int,
      );
      resolved[entry.key] = enumName ?? entry.value;
    } else {
      resolved[entry.key] = entry.value;
    }
  }

  return resolved;
}
