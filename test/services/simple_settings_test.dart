import 'package:flutter_test/flutter_test.dart';
import 'package:js_dash/services/settings_service.dart';
import 'package:js_dash/models/app_settings.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });
  group('Settings Service', () {
    late SettingsService settingsService;

    setUp(() {
      settingsService = SettingsService();
    });

    test('should load default settings when no saved settings exist', () async {
      final settings = await settingsService.loadSettings();

      expect(settings, isA<AppSettings>());
      expect(settings.window.width, equals(1200.0));
      expect(settings.window.height, equals(800.0));
      expect(settings.window.height, equals(800.0));
      expect(settings.connection.useSpoofMode, equals(true));
    });

    test('should save and load settings', () async {
      final originalSettings = AppSettings.defaults();

      // Save settings
      await settingsService.saveSettings(originalSettings);

      // Load settings
      final loadedSettings = await settingsService.loadSettings();

      expect(
        loadedSettings.window.width,
        equals(originalSettings.window.width),
      );
      expect(
        loadedSettings.window.height,
        equals(originalSettings.window.height),
      );
      expect(
        loadedSettings.window.height,
        equals(originalSettings.window.height),
      );
      expect(
        loadedSettings.connection.useSpoofMode,
        equals(originalSettings.connection.useSpoofMode),
      );
    });
  });
}
