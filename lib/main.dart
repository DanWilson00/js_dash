import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'mavlink/mavlink.dart';
import 'services/dialect_discovery.dart';
import 'services/settings_manager.dart';
import 'services/window/window_service.dart';
import 'providers/service_providers.dart';
import 'providers/ui_providers.dart';
import 'views/navigation/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize settings manager
  final settingsManager = SettingsManager();
  await settingsManager.initialize();

  // Load MAVLink metadata from selected dialect
  // Check user dialects first, then fall back to bundled assets
  final dialect = settingsManager.settings.connection.mavlinkDialect;
  final userDialectManager = DialectDiscovery.userDialectManager;
  String jsonString;

  if (await userDialectManager.hasDialect(dialect)) {
    // Load from user dialects folder
    jsonString = await userDialectManager.loadDialect(dialect);
  } else {
    // Load from bundled assets
    jsonString = await rootBundle.loadString('assets/mavlink/$dialect.json');
  }

  final registry = MavlinkMetadataRegistry();
  registry.loadFromJsonString(jsonString);

  // Initialize window management (desktop only)
  final windowService = WindowService.instance;
  if (windowService.isAvailable) {
    try {
      await windowService.initialize();

      // Configure window with saved settings
      final windowSettings = settingsManager.window;
      await windowService.setupWindow(
        size: windowSettings.size,
        position: windowSettings.position,
        maximized: windowSettings.maximized,
        title: 'MAVLink Dash',
      );
    } catch (e) {
      // Window management initialization failed
      debugPrint('Window management not available: $e');
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        // Override the settingsManagerProvider to use the pre-initialized instance
        settingsManagerProvider.overrideWith((ref) => settingsManager),
        // Override the mavlinkRegistryProvider to use the pre-loaded registry
        mavlinkRegistryProvider.overrideWithValue(registry),
      ],
      child: const SubmersibleJetskiApp(),
    ),
  );
}

class SubmersibleJetskiApp extends ConsumerStatefulWidget {
  const SubmersibleJetskiApp({super.key, this.autoStartMonitor = true});

  final bool autoStartMonitor;

  @override
  ConsumerState<SubmersibleJetskiApp> createState() =>
      _SubmersibleJetskiAppState();
}

class _SubmersibleJetskiAppState extends ConsumerState<SubmersibleJetskiApp>
    with WindowEventMixin {
  final _windowService = WindowService.instance;

  @override
  void initState() {
    super.initState();

    // Add window listener for desktop platforms
    if (_windowService.isAvailable) {
      try {
        _windowService.addListener(this);
        _windowService.setPreventClose(true);
      } catch (e) {
        // Window management not available on this platform
        debugPrint('Window listener not available: $e');
      }
    }
  }

  @override
  void dispose() {
    if (_windowService.isAvailable) {
      try {
        _windowService.removeListener(this);
      } catch (e) {
        // Window management not available on this platform
      }
    }
    super.dispose();
  }

  @override
  void onWindowResized() {
    _saveWindowState();
  }

  @override
  void onWindowMoved() {
    _saveWindowState();
  }

  @override
  void onWindowClose() async {
    // Hide window immediately to prevent perceived hang
    await _windowService.hide();

    try {
      await _saveWindowState();
      await ref.read(settingsManagerProvider).saveNow();
    } catch (e) {
      debugPrint('Error saving state on close: $e');
    } finally {
      await _windowService.destroy();
    }
  }

  @override
  void onWindowMaximize() {
    _saveWindowState();
  }

  @override
  void onWindowUnmaximize() {
    _saveWindowState();
  }

  Future<void> _saveWindowState() async {
    if (!_windowService.isAvailable) return;

    try {
      final size = await _windowService.getSize();
      final position = await _windowService.getPosition();
      final isMaximized = await _windowService.isMaximized();

      ref
          .read(settingsManagerProvider)
          .updateWindowState(
            size: size,
            position: position,
            maximized: isMaximized,
          );
    } catch (e) {
      // Window management not available on this platform
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);

    return MaterialApp(
      title: 'MAVLink Dash',
      theme: theme,
      home: MainNavigation(autoStartMonitor: widget.autoStartMonitor),
      debugShowCheckedModeBanner: false,
    );
  }
}
