import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../telemetry/realtime_data_display.dart';
import '../dashboard/jetshark_dashboard.dart';
import '../map/map_view.dart';
import '../../providers/service_providers.dart';
import '../../providers/ui_providers.dart';
import '../../providers/action_providers.dart';
import '../../services/settings_manager.dart';

class MainNavigation extends ConsumerStatefulWidget {
  final SettingsManager settingsManager;
  final bool autoStartMonitor;
  
  const MainNavigation({
    super.key, 
    required this.settingsManager,
    this.autoStartMonitor = true,
  });

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    if (_isInitialized) return;
    
    // Initialize telemetry repository
    final repository = ref.read(telemetryRepositoryProvider);
    repository.startTracking();
    
    // Load connection settings from stored configuration
    final connectionActions = ref.read(connectionActionsProvider);
    connectionActions.loadConnectionSettings();
    
    _isInitialized = true;
    
    // Auto-start monitoring if enabled
    if (widget.autoStartMonitor) {
      await _autoStartConnection();
    }
  }

  Future<void> _autoStartConnection() async {
    final settings = widget.settingsManager.settings;
    final connectionActions = ref.read(connectionActionsProvider);
    
    if (settings.connection.autoStartMonitor) {
      // Try to connect with saved settings
      await connectionActions.connectWithCurrentConfig();
    }
  }

  void _onItemTapped(int index) {
    final navigationActions = ref.read(navigationActionsProvider);
    navigationActions.navigateToView(index);
  }

  @override
  Widget build(BuildContext context) {
    // Watch providers for reactive updates
    final selectedIndex = ref.watch(selectedViewIndexProvider);
    final isConnected = ref.watch(isConnectedProvider);

    return Scaffold(
      body: _buildBody(selectedIndex),
      bottomNavigationBar: _buildBottomNavigation(selectedIndex, isConnected),
    );
  }

  Widget _buildBody(int selectedIndex) {
    return IndexedStack(
      index: selectedIndex,
      children: [
        const JetsharkDashboard(),
        RealtimeDataDisplay(settingsManager: widget.settingsManager),
        MapView(settingsManager: widget.settingsManager),
      ],
    );
  }

  Widget _buildBottomNavigation(int selectedIndex, bool isConnected) {
    return BottomNavigationBar(
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.show_chart),
          label: 'Telemetry',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map),
          label: 'Map',
        ),
      ],
      currentIndex: selectedIndex,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: isConnected ? Colors.green : Colors.blue,
      unselectedItemColor: Colors.grey,
    );
  }


  @override
  void dispose() {
    // Clean up is handled by providers automatically
    super.dispose();
  }
}