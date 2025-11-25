import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsService {
  static const String _settingsKey = 'app_settings_v1';

  /// Load complete app settings from storage
  Future<AppSettings> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);

      if (settingsJson != null) {
        final Map<String, dynamic> data = jsonDecode(settingsJson);
        return AppSettings.fromJson(data);
      }
    } catch (e) {
      // debugPrint('Error loading settings: $e');
    }

    // Return defaults if loading fails
    return AppSettings.defaults();
  }

  /// Save complete app settings to storage
  Future<void> saveSettings(AppSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(settings.toJson());
      await prefs.setString(_settingsKey, settingsJson);
    } catch (e) {
      // debugPrint('Error saving settings: $e');
    }
  }

  /// Clear all settings (reset to defaults)
  Future<void> clearAllSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_settingsKey);
    } catch (e) {
      // debugPrint('Error clearing settings: $e');
    }
  }

  /// Export settings to file (for backup/transfer)
  Future<String?> exportSettings() async {
    try {
      final settings = await loadSettings();
      return jsonEncode(settings.toJson());
    } catch (e) {
      // debugPrint('Error exporting settings: $e');
      return null;
    }
  }

  /// Import settings from JSON string
  Future<bool> importSettings(String settingsJson) async {
    try {
      final Map<String, dynamic> data = jsonDecode(settingsJson);
      final settings = AppSettings.fromJson(data);
      await saveSettings(settings);
      return true;
    } catch (e) {
      // debugPrint('Error importing settings: $e');
      return false;
    }
  }
}
