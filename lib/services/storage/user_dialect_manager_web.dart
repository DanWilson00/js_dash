// Web implementation of UserDialectManager
// Uses localStorage for dialect storage

import 'dart:convert';

import 'package:web/web.dart' as web;

import '../../mavlink/parser/mavlink_xml_parser.dart';

/// Information about a user dialect.
class UserDialectInfo {
  final String name;
  final String jsonPath;
  final String? xmlSourcePath;
  final DateTime importedAt;

  UserDialectInfo({
    required this.name,
    required this.jsonPath,
    this.xmlSourcePath,
    required this.importedAt,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'jsonPath': jsonPath,
    'xmlSourcePath': xmlSourcePath,
    'importedAt': importedAt.toIso8601String(),
  };

  factory UserDialectInfo.fromJson(Map<String, dynamic> json) => UserDialectInfo(
    name: json['name'] as String,
    jsonPath: json['jsonPath'] as String,
    xmlSourcePath: json['xmlSourcePath'] as String?,
    importedAt: DateTime.parse(json['importedAt'] as String),
  );
}

/// Web UserDialectManager using localStorage.
class UserDialectManager {
  static const String _storagePrefix = 'mavlink_dialect_';
  static const String _manifestKey = 'mavlink_dialects_manifest';

  Map<String, UserDialectInfo>? _manifest;

  /// Whether user dialect management is supported on this platform.
  bool get isSupported => true;

  /// Load the manifest of user dialects from localStorage.
  Map<String, UserDialectInfo> _loadManifest() {
    if (_manifest != null) return _manifest!;

    try {
      final jsonString = web.window.localStorage.getItem(_manifestKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final jsonData = json.decode(jsonString) as Map<String, dynamic>;
        _manifest = {};
        for (final entry in jsonData.entries) {
          _manifest![entry.key] = UserDialectInfo.fromJson(entry.value as Map<String, dynamic>);
        }
      } else {
        _manifest = {};
      }
    } catch (e) {
      _manifest = {};
    }

    return _manifest!;
  }

  /// Save the manifest to localStorage.
  void _saveManifest() {
    final jsonData = <String, dynamic>{};
    for (final entry in _manifest!.entries) {
      jsonData[entry.key] = entry.value.toJson();
    }
    web.window.localStorage.setItem(_manifestKey, json.encode(jsonData));
  }

  /// Import XML dialect from a map of file contents.
  ///
  /// [files] maps filename to XML content.
  /// [mainFile] is the main dialect file (e.g., "ardupilot.xml").
  ///
  /// Returns a record with dialect name and list of missing includes (if any).
  Future<(String dialectName, List<String> missingIncludes)> importFromXmlMap(
    Map<String, String> files,
    String mainFile,
  ) async {
    final parser = MavlinkXmlParser();
    final (jsonString, missingIncludes) = await parser.parseFromFileMap(files, mainFile);

    final dialectName = mainFile.replaceAll('.xml', '');

    // Store JSON in localStorage
    web.window.localStorage.setItem('$_storagePrefix$dialectName', jsonString);

    // Update manifest
    final manifest = _loadManifest();
    manifest[dialectName] = UserDialectInfo(
      name: dialectName,
      jsonPath: '$_storagePrefix$dialectName',
      xmlSourcePath: null, // Can't store XML source path on web
      importedAt: DateTime.now(),
    );
    _saveManifest();

    return (dialectName, missingIncludes);
  }

  /// Check if a user dialect exists.
  Future<bool> hasDialect(String dialectName) async {
    final manifest = _loadManifest();
    return manifest.containsKey(dialectName);
  }

  /// Load a user dialect's JSON content.
  Future<String> loadDialect(String dialectName) async {
    final manifest = _loadManifest();
    final info = manifest[dialectName];

    if (info == null) {
      throw Exception('Dialect not found: $dialectName');
    }

    final jsonString = web.window.localStorage.getItem(info.jsonPath);
    if (jsonString == null || jsonString.isEmpty) {
      throw Exception('Dialect data not found in storage: $dialectName');
    }

    return jsonString;
  }

  /// Get information about a user dialect.
  Future<UserDialectInfo?> getDialectInfo(String dialectName) async {
    final manifest = _loadManifest();
    return manifest[dialectName];
  }

  /// Get list of all user dialect names.
  Future<List<String>> getUserDialects() async {
    final manifest = _loadManifest();
    return manifest.keys.toList()..sort();
  }

  /// Get list of all user dialect info.
  Future<List<UserDialectInfo>> getUserDialectsInfo() async {
    final manifest = _loadManifest();
    final list = manifest.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  /// Delete a user dialect.
  Future<void> deleteDialect(String dialectName) async {
    final manifest = _loadManifest();
    final info = manifest[dialectName];

    if (info != null) {
      // Delete the JSON from localStorage
      web.window.localStorage.removeItem(info.jsonPath);

      // Remove from manifest
      manifest.remove(dialectName);
      _saveManifest();
    }
  }

  /// Clear the cached manifest.
  void clearCache() {
    _manifest = null;
  }

  // Stubs for methods not supported on web

  /// Import an XML dialect file (not supported on web - use importFromXmlMap).
  Future<String> importXmlDialect(String xmlPath) async {
    throw UnsupportedError(
      'File path-based XML import is not supported on web. '
      'Use importFromXmlMap() with file contents instead.',
    );
  }

  /// Reload a user dialect from its original XML source (not supported on web).
  Future<void> reloadDialect(String dialectName) async {
    throw UnsupportedError(
      'Dialect reload is not supported on web. '
      'Re-import the XML files to update the dialect.',
    );
  }
}
