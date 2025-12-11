/// MAVLink metadata registry for loading and querying dialect metadata.
///
/// Provides O(1) lookups for messages by ID or name, and enum resolution.
library;

import 'dart:convert';
import 'dart:io';

import 'mavlink_metadata.dart';

/// Registry for MAVLink message and enum metadata.
///
/// Load metadata once at startup, then use for fast lookups during parsing.
class MavlinkMetadataRegistry {
  String? _schemaVersion;
  String? _generatedAt;
  MavlinkDialectInfo? _dialect;

  // O(1) lookup maps
  final Map<int, MavlinkMessageMetadata> _messagesById = {};
  final Map<String, MavlinkMessageMetadata> _messagesByName = {};
  final Map<String, MavlinkEnumMetadata> _enums = {};

  /// Whether metadata has been loaded.
  bool get isLoaded => _messagesById.isNotEmpty;

  /// The loaded dialect information.
  MavlinkDialectInfo? get dialect => _dialect;

  /// Schema version of the loaded JSON.
  String? get schemaVersion => _schemaVersion;

  /// When the JSON was generated.
  String? get generatedAt => _generatedAt;

  /// Number of loaded messages.
  int get messageCount => _messagesById.length;

  /// Number of loaded enums.
  int get enumCount => _enums.length;

  /// Load metadata from a JSON file path.
  Future<void> loadFromFile(String path) async {
    final file = File(path);
    final jsonString = await file.readAsString();
    loadFromJsonString(jsonString);
  }

  /// Load metadata from a JSON string.
  void loadFromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    _loadFromJson(json);
  }

  /// Load metadata from parsed JSON.
  void _loadFromJson(Map<String, dynamic> json) {
    // Clear existing data
    _messagesById.clear();
    _messagesByName.clear();
    _enums.clear();

    // Load metadata info
    _schemaVersion = json['schema_version'] as String?;
    _generatedAt = json['generated_at'] as String?;

    if (json['dialect'] != null) {
      _dialect = MavlinkDialectInfo.fromJson(
        json['dialect'] as Map<String, dynamic>,
      );
    }

    // Load enums
    final enumsJson = json['enums'] as Map<String, dynamic>?;
    if (enumsJson != null) {
      for (final entry in enumsJson.entries) {
        final enumData = MavlinkEnumMetadata.fromJson(
          entry.value as Map<String, dynamic>,
        );
        _enums[enumData.name] = enumData;
      }
    }

    // Load messages
    final messagesJson = json['messages'] as Map<String, dynamic>?;
    if (messagesJson != null) {
      for (final entry in messagesJson.entries) {
        final msgData = MavlinkMessageMetadata.fromJson(
          entry.value as Map<String, dynamic>,
        );
        _messagesById[msgData.id] = msgData;
        _messagesByName[msgData.name] = msgData;
      }
    }
  }

  /// Get message metadata by ID. Returns null if not found.
  MavlinkMessageMetadata? getMessageById(int id) => _messagesById[id];

  /// Get message metadata by name. Returns null if not found.
  MavlinkMessageMetadata? getMessageByName(String name) => _messagesByName[name];

  /// Get enum metadata by name. Returns null if not found.
  MavlinkEnumMetadata? getEnum(String name) => _enums[name];

  /// Resolve an enum value to its name.
  ///
  /// Returns null if the enum or value is not found.
  String? resolveEnumValue(String enumName, int value) {
    return _enums[enumName]?.getValueName(value);
  }

  /// Get all message IDs.
  Iterable<int> get messageIds => _messagesById.keys;

  /// Get all message names.
  Iterable<String> get messageNames => _messagesByName.keys;

  /// Get all enum names.
  Iterable<String> get enumNames => _enums.keys;

  /// Get all messages.
  Iterable<MavlinkMessageMetadata> get messages => _messagesById.values;

  /// Get all enums.
  Iterable<MavlinkEnumMetadata> get enums => _enums.values;
}
