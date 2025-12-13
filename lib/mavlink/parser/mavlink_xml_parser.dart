/// MAVLink XML Parser
///
/// Parses MAVLink XML dialect definitions and generates JSON metadata
/// compatible with the MavlinkMetadataRegistry.
library;

import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import 'mavlink_crc.dart';

/// Type sizes in bytes for MAVLink types.
const Map<String, int> _typeSizes = {
  'int8_t': 1,
  'uint8_t': 1,
  'char': 1,
  'int16_t': 2,
  'uint16_t': 2,
  'int32_t': 4,
  'uint32_t': 4,
  'float': 4,
  'int64_t': 8,
  'uint64_t': 8,
  'double': 8,
};

/// Parsed field definition from XML.
class _FieldDef {
  final String name;
  final String type;
  final String baseType;
  final int arrayLength;
  final bool isExtension;
  final String? units;
  final String? enumType;
  final String? description;
  final String? display;
  final String? invalid;

  _FieldDef({
    required this.name,
    required this.type,
    required this.baseType,
    required this.arrayLength,
    required this.isExtension,
    this.units,
    this.enumType,
    this.description,
    this.display,
    this.invalid,
  });

  int get typeSize => _typeSizes[baseType] ?? 1;
}

/// Parsed enum entry from XML.
class _EnumEntry {
  final String name;
  final int value;
  final String description;

  _EnumEntry({
    required this.name,
    required this.value,
    required this.description,
  });
}

/// Parsed enum definition from XML.
class _EnumDef {
  final String name;
  final String description;
  final bool bitmask;
  final List<_EnumEntry> entries;

  _EnumDef({
    required this.name,
    required this.description,
    required this.bitmask,
    required this.entries,
  });
}

/// Parsed message definition from XML.
class _MessageDef {
  final int id;
  final String name;
  final String description;
  final List<_FieldDef> fields;

  _MessageDef({
    required this.id,
    required this.name,
    required this.description,
    required this.fields,
  });
}

/// Parsed dialect containing all messages and enums.
class _ParsedDialect {
  final Map<int, _MessageDef> messages;
  final Map<String, _EnumDef> enums;

  _ParsedDialect({
    required this.messages,
    required this.enums,
  });

  /// Merge another dialect into this one (child takes precedence).
  void merge(_ParsedDialect other) {
    for (final entry in other.messages.entries) {
      messages.putIfAbsent(entry.key, () => entry.value);
    }
    for (final entry in other.enums.entries) {
      enums.putIfAbsent(entry.key, () => entry.value);
    }
  }
}

/// MAVLink XML parser that generates JSON metadata.
class MavlinkXmlParser {
  /// Parse XML from an in-memory file map.
  ///
  /// This method is platform-independent and works on web.
  /// [files] maps filename (e.g., "common.xml") to XML content.
  /// [mainFile] is the entry point dialect file name.
  ///
  /// Returns a record containing the JSON string and list of any missing includes.
  Future<(String json, List<String> missingIncludes)> parseFromFileMap(
    Map<String, String> files,
    String mainFile,
  ) async {
    final xmlContent = files[mainFile];
    if (xmlContent == null) {
      throw Exception('Main file not found in map: $mainFile');
    }

    final dialectName = mainFile.replaceAll('.xml', '');
    final parsedFiles = <String>{};
    final missingIncludes = <String>[];

    final dialect = _parseFromMapRecursive(
      files,
      mainFile,
      parsedFiles,
      missingIncludes,
    );

    return (_generateJson(dialect, dialectName), missingIncludes);
  }

  _ParsedDialect _parseFromMapRecursive(
    Map<String, String> files,
    String fileName,
    Set<String> parsedFiles,
    List<String> missingIncludes,
  ) {
    // Prevent infinite loops
    if (parsedFiles.contains(fileName)) {
      return _ParsedDialect(messages: {}, enums: {});
    }
    parsedFiles.add(fileName);

    final xmlString = files[fileName];
    if (xmlString == null) {
      missingIncludes.add(fileName);
      return _ParsedDialect(messages: {}, enums: {});
    }

    final document = XmlDocument.parse(xmlString);
    final mavlinkElement = document.rootElement;

    if (mavlinkElement.name.local != 'mavlink') {
      throw Exception('Invalid MAVLink XML in $fileName: root element must be <mavlink>');
    }

    // Parse this file's content
    final messages = <int, _MessageDef>{};
    final enums = <String, _EnumDef>{};

    // Parse enums
    for (final enumsElement in mavlinkElement.findAllElements('enums')) {
      for (final enumElement in enumsElement.findAllElements('enum')) {
        final enumDef = _parseEnum(enumElement);
        enums[enumDef.name] = enumDef;
      }
    }

    // Parse messages
    for (final messagesElement in mavlinkElement.findAllElements('messages')) {
      for (final messageElement in messagesElement.findAllElements('message')) {
        final messageDef = _parseMessage(messageElement);
        messages[messageDef.id] = messageDef;
      }
    }

    final dialect = _ParsedDialect(messages: messages, enums: enums);

    // Process includes from the file map
    for (final includeElement in mavlinkElement.findAllElements('include')) {
      final includeFile = includeElement.innerText.trim();
      if (includeFile.isNotEmpty) {
        // Normalize include path - extract just the filename
        final normalizedName = includeFile.split('/').last.split('\\').last;

        final includedDialect = _parseFromMapRecursive(
          files,
          normalizedName,
          parsedFiles,
          missingIncludes,
        );
        // Merge included dialect (current file takes precedence)
        dialect.merge(includedDialect);
      }
    }

    return dialect;
  }

  /// Parse an XML file and generate JSON metadata string.
  ///
  /// Recursively resolves `<include>` tags relative to the XML file's directory.
  Future<String> parseFile(String xmlPath) async {
    final file = File(xmlPath);
    if (!await file.exists()) {
      throw Exception('XML file not found: $xmlPath');
    }

    final xmlString = await file.readAsString();
    final baseDir = file.parent.path;
    final dialectName = _extractDialectName(xmlPath);

    return parseXmlString(xmlString, baseDir, dialectName);
  }

  /// Parse XML string and generate JSON metadata.
  ///
  /// [baseDir] is used to resolve `<include>` paths.
  /// [dialectName] is used in the output metadata.
  Future<String> parseXmlString(
    String xmlString,
    String baseDir,
    String dialectName,
  ) async {
    final parsedFiles = <String>{};
    final dialect = await _parseXmlRecursive(xmlString, baseDir, parsedFiles);
    return _generateJson(dialect, dialectName);
  }

  /// Parse XML file path and generate JSON metadata.
  Future<String> parseXmlPath(String xmlPath) async {
    final file = File(xmlPath);
    if (!await file.exists()) {
      throw Exception('XML file not found: $xmlPath');
    }

    final parsedFiles = <String>{};
    final resolvedPath = file.absolute.path;
    final dialect = await _parseXmlFileRecursive(resolvedPath, parsedFiles);
    final dialectName = _extractDialectName(xmlPath);

    return _generateJson(dialect, dialectName);
  }

  String _extractDialectName(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    return fileName.replaceAll('.xml', '');
  }

  Future<_ParsedDialect> _parseXmlFileRecursive(
    String xmlPath,
    Set<String> parsedFiles,
  ) async {
    // Normalize path
    final file = File(xmlPath);
    final resolvedPath = file.absolute.path;

    // Prevent infinite loops
    if (parsedFiles.contains(resolvedPath)) {
      return _ParsedDialect(messages: {}, enums: {});
    }
    parsedFiles.add(resolvedPath);

    final xmlString = await file.readAsString();
    final baseDir = file.parent.path;

    return _parseXmlRecursive(xmlString, baseDir, parsedFiles);
  }

  Future<_ParsedDialect> _parseXmlRecursive(
    String xmlString,
    String baseDir,
    Set<String> parsedFiles,
  ) async {
    final document = XmlDocument.parse(xmlString);
    final mavlinkElement = document.rootElement;

    if (mavlinkElement.name.local != 'mavlink') {
      throw Exception('Invalid MAVLink XML: root element must be <mavlink>');
    }

    // Parse this file's content
    final messages = <int, _MessageDef>{};
    final enums = <String, _EnumDef>{};

    // Parse enums
    for (final enumsElement in mavlinkElement.findAllElements('enums')) {
      for (final enumElement in enumsElement.findAllElements('enum')) {
        final enumDef = _parseEnum(enumElement);
        enums[enumDef.name] = enumDef;
      }
    }

    // Parse messages
    for (final messagesElement in mavlinkElement.findAllElements('messages')) {
      for (final messageElement in messagesElement.findAllElements('message')) {
        final messageDef = _parseMessage(messageElement);
        messages[messageDef.id] = messageDef;
      }
    }

    final dialect = _ParsedDialect(messages: messages, enums: enums);

    // Process includes
    for (final includeElement in mavlinkElement.findAllElements('include')) {
      final includeFile = includeElement.innerText.trim();
      if (includeFile.isNotEmpty) {
        final includePath = '$baseDir${Platform.pathSeparator}$includeFile';
        final includeFileObj = File(includePath);

        if (await includeFileObj.exists()) {
          final includedDialect = await _parseXmlFileRecursive(
            includePath,
            parsedFiles,
          );
          // Merge included dialect (current file takes precedence)
          dialect.merge(includedDialect);
        }
      }
    }

    return dialect;
  }

  _EnumDef _parseEnum(XmlElement element) {
    final name = element.getAttribute('name') ?? '';
    final bitmask = element.getAttribute('bitmask') == 'true';

    String description = '';
    final descElement = element.getElement('description');
    if (descElement != null) {
      description = descElement.innerText.trim();
    }

    final entries = <_EnumEntry>[];
    for (final entryElement in element.findAllElements('entry')) {
      final entryName = entryElement.getAttribute('name') ?? '';
      final valueStr = entryElement.getAttribute('value') ?? '0';
      final value = int.tryParse(valueStr) ?? 0;

      String entryDescription = '';
      final entryDescElement = entryElement.getElement('description');
      if (entryDescElement != null) {
        entryDescription = entryDescElement.innerText.trim();
      }

      entries.add(_EnumEntry(
        name: entryName,
        value: value,
        description: entryDescription,
      ));
    }

    return _EnumDef(
      name: name,
      description: description,
      bitmask: bitmask,
      entries: entries,
    );
  }

  _MessageDef _parseMessage(XmlElement element) {
    final id = int.tryParse(element.getAttribute('id') ?? '0') ?? 0;
    final name = element.getAttribute('name') ?? '';

    String description = '';
    final descElement = element.getElement('description');
    if (descElement != null) {
      description = descElement.innerText.trim();
    }

    final fields = <_FieldDef>[];
    bool inExtensions = false;

    for (final child in element.children) {
      if (child is XmlElement) {
        if (child.name.local == 'extensions') {
          inExtensions = true;
        } else if (child.name.local == 'field') {
          final fieldDef = _parseField(child, inExtensions);
          fields.add(fieldDef);
        }
      }
    }

    return _MessageDef(
      id: id,
      name: name,
      description: description,
      fields: fields,
    );
  }

  _FieldDef _parseField(XmlElement element, bool isExtension) {
    final name = element.getAttribute('name') ?? '';
    final type = element.getAttribute('type') ?? 'uint8_t';
    final units = element.getAttribute('units');
    final enumType = element.getAttribute('enum');
    final display = element.getAttribute('display');
    final invalid = element.getAttribute('invalid');
    final description = element.innerText.trim();

    // Parse base type and array length
    final baseType = _getBaseType(type);
    final arrayLength = _getArrayLength(type);

    return _FieldDef(
      name: name,
      type: type,
      baseType: baseType,
      arrayLength: arrayLength,
      isExtension: isExtension,
      units: units,
      enumType: enumType,
      description: description.isEmpty ? null : description,
      display: display,
      invalid: invalid,
    );
  }

  String _getBaseType(String type) {
    // Handle special mavlink_version type
    if (type == 'uint8_t_mavlink_version') {
      return 'uint8_t';
    }
    // Handle array types
    if (type.contains('[')) {
      return type.split('[').first;
    }
    return type;
  }

  int _getArrayLength(String type) {
    if (type.contains('[')) {
      final start = type.indexOf('[') + 1;
      final end = type.indexOf(']');
      return int.tryParse(type.substring(start, end)) ?? 1;
    }
    return 1;
  }

  /// Order fields for serialization and CRC calculation.
  ///
  /// Non-extension fields are sorted by type size (largest first).
  /// Extension fields keep their original order and come after.
  List<_FieldDef> _orderFields(List<_FieldDef> fields) {
    final nonExt = fields.where((f) => !f.isExtension).toList();
    final ext = fields.where((f) => f.isExtension).toList();

    // Sort non-extension fields by type size descending
    nonExt.sort((a, b) => b.typeSize.compareTo(a.typeSize));

    return [...nonExt, ...ext];
  }

  /// Calculate CRC extra for a message.
  int _calculateCrcExtra(String messageName, List<_FieldDef> fields) {
    final crc = MavlinkCrc();
    crc.accumulateString('$messageName ');

    // Order fields by size (largest first), extensions excluded from CRC
    final ordered = _orderFields(fields);

    for (final field in ordered) {
      if (field.isExtension) continue;

      crc.accumulateString('${field.baseType} ');
      crc.accumulateString('${field.name} ');

      if (field.arrayLength > 1) {
        crc.accumulate(field.arrayLength);
      }
    }

    return (crc.crc & 0xFF) ^ (crc.crc >> 8);
  }

  /// Calculate field offsets after reordering.
  List<Map<String, dynamic>> _calculateFieldsWithOffsets(List<_FieldDef> fields) {
    final ordered = _orderFields(fields);
    int offset = 0;
    final result = <Map<String, dynamic>>[];

    for (final field in ordered) {
      final size = field.typeSize;
      final totalSize = size * field.arrayLength;

      result.add({
        'name': field.name,
        'type': field.type,
        'base_type': field.baseType,
        'offset': offset,
        'size': size,
        'array_length': field.arrayLength,
        'units': field.units,
        'enum': field.enumType,
        'invalid': field.invalid,
        'display': field.display,
        'description': field.description ?? '',
        'extension': field.isExtension,
      });

      offset += totalSize;
    }

    return result;
  }

  /// Generate JSON string from parsed dialect.
  String _generateJson(_ParsedDialect dialect, String dialectName) {
    // Build enums
    final enumsJson = <String, dynamic>{};
    for (final entry in dialect.enums.entries) {
      final enumDef = entry.value;
      final entriesJson = <String, dynamic>{};

      for (final enumEntry in enumDef.entries) {
        entriesJson[enumEntry.value.toString()] = {
          'name': enumEntry.name,
          'value': enumEntry.value,
          'description': enumEntry.description,
        };
      }

      enumsJson[enumDef.name] = {
        'name': enumDef.name,
        'description': enumDef.description,
        'bitmask': enumDef.bitmask,
        'entries': entriesJson,
      };
    }

    // Build messages
    final messagesJson = <String, dynamic>{};
    for (final entry in dialect.messages.entries) {
      final msg = entry.value;
      final crcExtra = _calculateCrcExtra(msg.name, msg.fields);
      final fieldsWithOffsets = _calculateFieldsWithOffsets(msg.fields);

      // Calculate encoded length (sum of all non-extension field sizes)
      int encodedLength = 0;
      for (final field in fieldsWithOffsets) {
        if (field['extension'] != true) {
          encodedLength += (field['size'] as int) * (field['array_length'] as int);
        }
      }

      messagesJson[msg.id.toString()] = {
        'id': msg.id,
        'name': msg.name,
        'description': msg.description,
        'crc_extra': crcExtra,
        'encoded_length': encodedLength,
        'fields': fieldsWithOffsets,
      };
    }

    final output = {
      'schema_version': '1.0.0',
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'dialect': {
        'name': dialectName,
        'version': 3,
      },
      'enums': enumsJson,
      'messages': messagesJson,
    };

    return const JsonEncoder.withIndent('  ').convert(output);
  }
}
