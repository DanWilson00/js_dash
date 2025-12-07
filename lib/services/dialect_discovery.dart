import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Discovers available MAVLink dialect JSON files from assets/mavlink/ folder.
///
/// This allows new dialects to be added by simply dropping JSON files
/// into the assets/mavlink/ directory.
class DialectDiscovery {
  /// Get list of available dialect names from asset manifest.
  ///
  /// Returns dialect names without the .json extension (e.g., "common", "ardupilotmega").
  static Future<List<String>> getAvailableDialects() async {
    try {
      // Read the AssetManifest to find all JSON files in assets/mavlink/
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final manifest = json.decode(manifestJson) as Map<String, dynamic>;

      final dialects = <String>[];
      for (final key in manifest.keys) {
        if (key.startsWith('assets/mavlink/') && key.endsWith('.json')) {
          // Extract dialect name: "assets/mavlink/common.json" -> "common"
          final filename = key.split('/').last;
          final dialectName = filename.replaceAll('.json', '');
          dialects.add(dialectName);
        }
      }

      // Sort alphabetically for consistent ordering
      return dialects..sort();
    } catch (e) {
      // Fallback to common if manifest can't be read
      return ['common'];
    }
  }
}
