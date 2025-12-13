// Stub implementation of UserDialectManager
// Used on platforms without file system access (web)

import 'dart:async';

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

/// Stub UserDialectManager for platforms without file system access.
/// User dialect import is not supported on web - use bundled dialects instead.
class UserDialectManager {
  /// Whether user dialect management is supported on this platform.
  bool get isSupported => false;

  /// Check if a user dialect exists (always false on web).
  Future<bool> hasDialect(String dialectName) async => false;

  /// Load a user dialect's JSON content (throws on web).
  Future<String> loadDialect(String dialectName) async {
    throw UnsupportedError(
      'User dialects are not supported on this platform. '
      'Use bundled dialects from assets/mavlink/ instead.',
    );
  }

  /// Import an XML dialect file (throws on web).
  Future<String> importXmlDialect(String xmlPath) async {
    throw UnsupportedError(
      'XML dialect import is not supported on this platform. '
      'Pre-convert XML to JSON and include in assets/mavlink/ instead.',
    );
  }

  /// Reload a user dialect from its original XML source (throws on web).
  Future<void> reloadDialect(String dialectName) async {
    throw UnsupportedError(
      'Dialect reload is not supported on this platform.',
    );
  }

  /// Get information about a user dialect (always null on web).
  Future<UserDialectInfo?> getDialectInfo(String dialectName) async => null;

  /// Get list of all user dialect names (always empty on web).
  Future<List<String>> getUserDialects() async => [];

  /// Get list of all user dialect info (always empty on web).
  Future<List<UserDialectInfo>> getUserDialectsInfo() async => [];

  /// Delete a user dialect (no-op on web).
  Future<void> deleteDialect(String dialectName) async {}

  /// Clear the cached manifest (no-op on web).
  void clearCache() {}

  /// Import XML dialect from a map of file contents (throws on stub).
  Future<(String dialectName, List<String> missingIncludes)> importFromXmlMap(
    Map<String, String> files,
    String mainFile,
  ) async {
    throw UnsupportedError(
      'XML dialect import is not supported on this platform.',
    );
  }
}
