import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import 'user_dialect_manager.dart';

/// Information about an available dialect.
class DialectInfo {
  final String name;
  final bool isUserDialect;
  final String? xmlSourcePath;

  const DialectInfo({
    required this.name,
    required this.isUserDialect,
    this.xmlSourcePath,
  });

  /// Display name for UI (adds indicator for user dialects).
  String get displayName => isUserDialect ? '$name (custom)' : name;
}

/// Discovers available MAVLink dialect JSON files from assets/mavlink/ folder
/// and user-imported dialects.
///
/// This allows new dialects to be added by simply dropping JSON files
/// into the assets/mavlink/ directory or importing XML files.
class DialectDiscovery {
  static final UserDialectManager _userDialectManager = UserDialectManager();

  /// Get list of available dialect names (bundled + user).
  ///
  /// Returns dialect names without the .json extension (e.g., "common", "ardupilotmega").
  static Future<List<String>> getAvailableDialects() async {
    final infos = await getAvailableDialectsInfo();
    return infos.map((i) => i.name).toList();
  }

  /// Get list of available dialects with full info.
  static Future<List<DialectInfo>> getAvailableDialectsInfo() async {
    final dialects = <DialectInfo>[];

    // Get bundled dialects from assets
    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final manifest = json.decode(manifestJson) as Map<String, dynamic>;

      for (final key in manifest.keys) {
        if (key.startsWith('assets/mavlink/') && key.endsWith('.json')) {
          final filename = key.split('/').last;
          final dialectName = filename.replaceAll('.json', '');
          dialects.add(DialectInfo(
            name: dialectName,
            isUserDialect: false,
          ));
        }
      }
    } catch (e) {
      // Fallback to common if manifest can't be read
      dialects.add(const DialectInfo(name: 'common', isUserDialect: false));
    }

    // Get user dialects
    try {
      final userDialects = await _userDialectManager.getUserDialectsInfo();
      for (final info in userDialects) {
        // Don't add if a bundled dialect with same name exists
        if (!dialects.any((d) => d.name == info.name)) {
          dialects.add(DialectInfo(
            name: info.name,
            isUserDialect: true,
            xmlSourcePath: info.xmlSourcePath,
          ));
        }
      }
    } catch (e) {
      // Ignore user dialect errors
    }

    // Sort alphabetically
    dialects.sort((a, b) => a.name.compareTo(b.name));
    return dialects;
  }

  /// Check if a dialect is a user dialect.
  static Future<bool> isUserDialect(String dialectName) async {
    return await _userDialectManager.hasDialect(dialectName);
  }

  /// Get the UserDialectManager instance for direct operations.
  static UserDialectManager get userDialectManager => _userDialectManager;
}
