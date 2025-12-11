/// MAVLink metadata data classes.
///
/// These classes represent the structure of MAVLink message and enum
/// metadata loaded from the JSON dialect file.
library;

/// Metadata for a single enum entry (value/name pair).
class MavlinkEnumEntry {
  final String name;
  final int value;
  final String description;

  const MavlinkEnumEntry({
    required this.name,
    required this.value,
    required this.description,
  });

  factory MavlinkEnumEntry.fromJson(Map<String, dynamic> json) {
    return MavlinkEnumEntry(
      name: json['name'] as String,
      value: json['value'] as int,
      description: json['description'] as String? ?? '',
    );
  }
}

/// Metadata for an enum type.
class MavlinkEnumMetadata {
  final String name;
  final String description;
  final bool bitmask;
  final Map<int, MavlinkEnumEntry> entries;

  const MavlinkEnumMetadata({
    required this.name,
    required this.description,
    required this.bitmask,
    required this.entries,
  });

  factory MavlinkEnumMetadata.fromJson(Map<String, dynamic> json) {
    final entriesJson = json['entries'] as Map<String, dynamic>;
    final entries = <int, MavlinkEnumEntry>{};

    for (final entry in entriesJson.entries) {
      final entryData =
          MavlinkEnumEntry.fromJson(entry.value as Map<String, dynamic>);
      entries[entryData.value] = entryData;
    }

    return MavlinkEnumMetadata(
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      bitmask: json['bitmask'] as bool? ?? false,
      entries: entries,
    );
  }

  /// Get the name for a given enum value.
  String? getValueName(int value) => entries[value]?.name;

  /// Get the description for a given enum value.
  String? getValueDescription(int value) => entries[value]?.description;
}

/// Metadata for a message field.
class MavlinkFieldMetadata {
  final String name;
  final String type;
  final String baseType;
  final int offset;
  final int size;
  final int arrayLength;
  final String? units;
  final String? enumType;
  final String? invalid;
  final String? display;
  final String description;
  final bool extension;

  const MavlinkFieldMetadata({
    required this.name,
    required this.type,
    required this.baseType,
    required this.offset,
    required this.size,
    required this.arrayLength,
    this.units,
    this.enumType,
    this.invalid,
    this.display,
    required this.description,
    required this.extension,
  });

  factory MavlinkFieldMetadata.fromJson(Map<String, dynamic> json) {
    return MavlinkFieldMetadata(
      name: json['name'] as String,
      type: json['type'] as String,
      baseType: json['base_type'] as String,
      offset: json['offset'] as int,
      size: json['size'] as int,
      arrayLength: json['array_length'] as int? ?? 1,
      units: json['units'] as String?,
      enumType: json['enum'] as String?,
      invalid: json['invalid'] as String?,
      display: json['display'] as String?,
      description: json['description'] as String? ?? '',
      extension: json['extension'] as bool? ?? false,
    );
  }

  /// Whether this field is an array.
  bool get isArray => arrayLength > 1;

  /// Total size of this field in bytes (size * arrayLength).
  int get totalSize => size * arrayLength;
}

/// Metadata for a MAVLink message.
class MavlinkMessageMetadata {
  final int id;
  final String name;
  final String description;
  final int crcExtra;
  final int encodedLength;
  final List<MavlinkFieldMetadata> fields;

  // Pre-computed lookup for fast field access by name
  late final Map<String, MavlinkFieldMetadata> _fieldsByName;

  MavlinkMessageMetadata({
    required this.id,
    required this.name,
    required this.description,
    required this.crcExtra,
    required this.encodedLength,
    required this.fields,
  }) {
    _fieldsByName = {for (final f in fields) f.name: f};
  }

  factory MavlinkMessageMetadata.fromJson(Map<String, dynamic> json) {
    final fieldsJson = json['fields'] as List<dynamic>;
    final fields = fieldsJson
        .map((f) => MavlinkFieldMetadata.fromJson(f as Map<String, dynamic>))
        .toList();

    return MavlinkMessageMetadata(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      crcExtra: json['crc_extra'] as int,
      encodedLength: json['encoded_length'] as int,
      fields: fields,
    );
  }

  /// Get field metadata by name. Returns null if not found.
  MavlinkFieldMetadata? getField(String name) => _fieldsByName[name];

  /// Get all non-extension fields.
  List<MavlinkFieldMetadata> get nonExtensionFields =>
      fields.where((f) => !f.extension).toList();

  /// Get all extension fields.
  List<MavlinkFieldMetadata> get extensionFields =>
      fields.where((f) => f.extension).toList();
}

/// Dialect information.
class MavlinkDialectInfo {
  final String name;
  final int version;

  const MavlinkDialectInfo({
    required this.name,
    required this.version,
  });

  factory MavlinkDialectInfo.fromJson(Map<String, dynamic> json) {
    return MavlinkDialectInfo(
      name: json['name'] as String,
      version: json['version'] as int,
    );
  }
}
