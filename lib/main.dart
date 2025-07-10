import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'core/service_locator.dart';
import 'providers/ui_providers.dart';
import 'services/settings_manager.dart';
import 'views/navigation/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize settings manager and register in DI container
  final settingsManager = SettingsManager();
  await settingsManager.initialize();
  GetIt.registerSingleton<SettingsManager>(settingsManager);
  debugPrint('Settings initialized successfully');
  
  // Initialize window management (desktop only)
  try {
    await windowManager.ensureInitialized();
    
    // Restore window state
    final windowSettings = settingsManager.window;
    if (windowSettings.maximized) {
      await windowManager.maximize();
    } else {
      await windowManager.setSize(windowSettings.size);
      if (windowSettings.position != null) {
        await windowManager.setPosition(windowSettings.position!);
      }
    }
  } catch (e) {
    // Window management not available on this platform
    debugPrint('Window management not available: $e');
  }
  
  runApp(ProviderScope(
    child: SubmersibleJetskiApp(settingsManager: settingsManager),
  ));
}

class SubmersibleJetskiApp extends ConsumerStatefulWidget {
  const SubmersibleJetskiApp({
    super.key, 
    required this.settingsManager,
    this.autoStartMonitor = true,
  });

  final SettingsManager settingsManager;
  final bool autoStartMonitor;

  @override
  ConsumerState<SubmersibleJetskiApp> createState() => _SubmersibleJetskiAppState();
}

class _SubmersibleJetskiAppState extends ConsumerState<SubmersibleJetskiApp> with WindowListener {
  
  @override
  void initState() {
    super.initState();
    
    // Add window listener for desktop platforms
    try {
      windowManager.addListener(this);
    } catch (e) {
      // Window management not available on this platform
      debugPrint('Window listener not available: $e');
    }
  }

  @override
  void dispose() {
    try {
      windowManager.removeListener(this);
    } catch (e) {
      // Window management not available on this platform
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
  void onWindowMaximize() {
    _saveWindowState();
  }

  @override
  void onWindowUnmaximize() {
    _saveWindowState();
  }

  void _saveWindowState() async {
    try {
      final size = await windowManager.getSize();
      final position = await windowManager.getPosition();
      final isMaximized = await windowManager.isMaximized();
      
      widget.settingsManager.updateWindowState(
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
      title: 'Submersible Jetski Dashboard',
      theme: theme,
      home: MainNavigation(
        settingsManager: widget.settingsManager,
        autoStartMonitor: widget.autoStartMonitor,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
