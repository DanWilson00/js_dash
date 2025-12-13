// Desktop/mobile implementation of UserDialectManager
// Uses dart:io for file system access

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

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

/// Manages user-imported MAVLink dialects on desktop/mobile platforms.
class UserDialectManager {
  static const String _dialectsFolderName = 'mavlink_dialects';
  static const String _manifestFileName = 'dialects_manifest.json';

  Directory? _dialectsDir;
  Map<String, UserDialectInfo>? _manifest;

  /// Whether user dialect management is supported on this platform.
  bool get isSupported => true;

  /// Get the directory for storing user dialects.
  Future<Directory> get dialectsDirectory async {
    if (_dialectsDir != null) return _dialectsDir!;

    final appDir = await getApplicationDocumentsDirectory();
    _dialectsDir = Directory('${appDir.path}${Platform.pathSeparator}$_dialectsFolderName');

    if (!await _dialectsDir!.exists()) {
      await _dialectsDir!.create(recursive: true);
    }

    return _dialectsDir!;
  }

  /// Load the manifest of user dialects.
  Future<Map<String, UserDialectInfo>> _loadManifest() async {
    if (_manifest != null) return _manifest!;

    final dir = await dialectsDirectory;
    final manifestFile = File('${dir.path}${Platform.pathSeparator}$_manifestFileName');

    if (await manifestFile.exists()) {
      try {
        final jsonString = await manifestFile.readAsString();
        final jsonData = json.decode(jsonString) as Map<String, dynamic>;
        _manifest = {};
        for (final entry in jsonData.entries) {
          _manifest![entry.key] = UserDialectInfo.fromJson(entry.value as Map<String, dynamic>);
        }
      } catch (e) {
        _manifest = {};
      }
    } else {
      _manifest = {};
    }

    return _manifest!;
  }

  /// Save the manifest of user dialects.
  Future<void> _saveManifest() async {
    final dir = await dialectsDirectory;
    final manifestFile = File('${dir.path}${Platform.pathSeparator}$_manifestFileName');

    final jsonData = <String, dynamic>{};
    for (final entry in _manifest!.entries) {
      jsonData[entry.key] = entry.value.toJson();
    }

    await manifestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(jsonData),
    );
  }

  /// Import an XML dialect file.
  ///
  /// Returns the dialect name on success.
  Future<String> importXmlDialect(String xmlPath) async {
    final parser = MavlinkXmlParser();
    final jsonString = await parser.parseFile(xmlPath);

    // Extract dialect name from filename
    final fileName = xmlPath.split(Platform.pathSeparator).last;
    final dialectName = fileName.replaceAll('.xml', '');

    // Save JSON to user dialects folder
    final dir = await dialectsDirectory;
    final jsonPath = '${dir.path}${Platform.pathSeparator}$dialectName.json';
    final jsonFile = File(jsonPath);
    await jsonFile.writeAsString(jsonString);

    // Update manifest
    final manifest = await _loadManifest();
    manifest[dialectName] = UserDialectInfo(
      name: dialectName,
      jsonPath: jsonPath,
      xmlSourcePath: xmlPath,
      importedAt: DateTime.now(),
    );
    await _saveManifest();

    return dialectName;
  }

  /// Reload a user dialect from its original XML source.
  ///
  /// Throws if the dialect doesn't have an XML source path stored.
  Future<void> reloadDialect(String dialectName) async {
    final manifest = await _loadManifest();
    final info = manifest[dialectName];

    if (info == null) {
      throw Exception('Dialect not found: $dialectName');
    }

    if (info.xmlSourcePath == null) {
      throw Exception('No XML source path stored for dialect: $dialectName');
    }

    // Re-parse the XML and save
    await importXmlDialect(info.xmlSourcePath!);
  }

  /// Check if a user dialect exists.
  Future<bool> hasDialect(String dialectName) async {
    final manifest = await _loadManifest();
    return manifest.containsKey(dialectName);
  }

  /// Load a user dialect's JSON content.
  Future<String> loadDialect(String dialectName) async {
    final manifest = await _loadManifest();
    final info = manifest[dialectName];

    if (info == null) {
      throw Exception('Dialect not found: $dialectName');
    }

    final jsonFile = File(info.jsonPath);
    if (!await jsonFile.exists()) {
      throw Exception('Dialect JSON file not found: ${info.jsonPath}');
    }

    return await jsonFile.readAsString();
  }

  /// Get information about a user dialect.
  Future<UserDialectInfo?> getDialectInfo(String dialectName) async {
    final manifest = await _loadManifest();
    return manifest[dialectName];
  }

  /// Get list of all user dialect names.
  Future<List<String>> getUserDialects() async {
    final manifest = await _loadManifest();
    return manifest.keys.toList()..sort();
  }

  /// Get list of all user dialect info.
  Future<List<UserDialectInfo>> getUserDialectsInfo() async {
    final manifest = await _loadManifest();
    final list = manifest.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  /// Delete a user dialect.
  Future<void> deleteDialect(String dialectName) async {
    final manifest = await _loadManifest();
    final info = manifest[dialectName];

    if (info != null) {
      // Delete the JSON file
      final jsonFile = File(info.jsonPath);
      if (await jsonFile.exists()) {
        await jsonFile.delete();
      }

      // Remove from manifest
      manifest.remove(dialectName);
      await _saveManifest();
    }
  }

  /// Clear the cached manifest (forces reload on next access).
  void clearCache() {
    _manifest = null;
    _dialectsDir = null;
  }

  /// Import XML dialect from a map of file contents.
  ///
  /// On desktop, this saves the JSON to the dialects folder.
  Future<(String dialectName, List<String> missingIncludes)> importFromXmlMap(
    Map<String, String> files,
    String mainFile,
  ) async {
    final parser = MavlinkXmlParser();
    final (jsonString, missingIncludes) = await parser.parseFromFileMap(files, mainFile);

    final dialectName = mainFile.replaceAll('.xml', '');

    // Save JSON to user dialects folder
    final dir = await dialectsDirectory;
    final jsonPath = '${dir.path}${Platform.pathSeparator}$dialectName.json';
    final jsonFile = File(jsonPath);
    await jsonFile.writeAsString(jsonString);

    // Update manifest
    final manifest = await _loadManifest();
    manifest[dialectName] = UserDialectInfo(
      name: dialectName,
      jsonPath: jsonPath,
      xmlSourcePath: null, // No single source path for map-based import
      importedAt: DateTime.now(),
    );
    await _saveManifest();

    return (dialectName, missingIncludes);
  }
}
