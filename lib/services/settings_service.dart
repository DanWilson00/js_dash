import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsService {
  static const String _settingsKey = 'app_settings_v1';
  static const String _windowStateKey = 'window_state';
  static const String _plotConfigKey = 'plot_configurations';
  static const String _connectionKey = 'connection_settings';
  static const String _navigationKey = 'navigation_settings';

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
      debugPrint('Error loading settings: $e');
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
      debugPrint('Error saving settings: $e');
    }
  }

  /// Save just window state (frequent updates)
  Future<void> saveWindowState(WindowSettings windowSettings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final windowJson = jsonEncode(windowSettings.toJson());
      await prefs.setString(_windowStateKey, windowJson);
    } catch (e) {
      debugPrint('Error saving window state: $e');
    }
  }

  /// Load window state separately for quick startup
  Future<WindowSettings> loadWindowState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final windowJson = prefs.getString(_windowStateKey);
      
      if (windowJson != null) {
        final Map<String, dynamic> data = jsonDecode(windowJson);
        return WindowSettings.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error loading window state: $e');
    }
    
    return WindowSettings.defaults();
  }

  /// Save plot configurations (frequent updates)
  Future<void> savePlotSettings(PlotSettings plotSettings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final plotJson = jsonEncode(plotSettings.toJson());
      await prefs.setString(_plotConfigKey, plotJson);
    } catch (e) {
      debugPrint('Error saving plot settings: $e');
    }
  }

  /// Load plot configurations
  Future<PlotSettings> loadPlotSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final plotJson = prefs.getString(_plotConfigKey);
      
      if (plotJson != null) {
        final Map<String, dynamic> data = jsonDecode(plotJson);
        return PlotSettings.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error loading plot settings: $e');
    }
    
    return PlotSettings.defaults();
  }

  /// Save connection settings
  Future<void> saveConnectionSettings(ConnectionSettings connectionSettings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final connectionJson = jsonEncode(connectionSettings.toJson());
      await prefs.setString(_connectionKey, connectionJson);
    } catch (e) {
      debugPrint('Error saving connection settings: $e');
    }
  }

  /// Load connection settings
  Future<ConnectionSettings> loadConnectionSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final connectionJson = prefs.getString(_connectionKey);
      
      if (connectionJson != null) {
        final Map<String, dynamic> data = jsonDecode(connectionJson);
        return ConnectionSettings.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error loading connection settings: $e');
    }
    
    return ConnectionSettings.defaults();
  }

  /// Save navigation state
  Future<void> saveNavigationSettings(NavigationSettings navigationSettings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final navigationJson = jsonEncode(navigationSettings.toJson());
      await prefs.setString(_navigationKey, navigationJson);
    } catch (e) {
      debugPrint('Error saving navigation settings: $e');
    }
  }

  /// Load navigation state
  Future<NavigationSettings> loadNavigationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final navigationJson = prefs.getString(_navigationKey);
      
      if (navigationJson != null) {
        final Map<String, dynamic> data = jsonDecode(navigationJson);
        return NavigationSettings.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error loading navigation settings: $e');
    }
    
    return NavigationSettings.defaults();
  }

  /// Clear all settings (reset to defaults)
  Future<void> clearAllSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_settingsKey);
      await prefs.remove(_windowStateKey);
      await prefs.remove(_plotConfigKey);
      await prefs.remove(_connectionKey);
      await prefs.remove(_navigationKey);
    } catch (e) {
      debugPrint('Error clearing settings: $e');
    }
  }

  /// Export settings to file (for backup/transfer)
  Future<String?> exportSettings() async {
    try {
      final settings = await loadSettings();
      return jsonEncode(settings.toJson());
    } catch (e) {
      debugPrint('Error exporting settings: $e');
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
      debugPrint('Error importing settings: $e');
      return false;
    }
  }
}