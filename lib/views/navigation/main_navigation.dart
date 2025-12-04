import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../telemetry/realtime_data_display.dart';
import '../dashboard/jetshark_dashboard.dart';
import '../map/map_view.dart';
import '../../providers/service_providers.dart';
import '../../providers/ui_providers.dart';
import '../../providers/action_providers.dart';
import '../../core/connection_config.dart';

class MainNavigation extends ConsumerStatefulWidget {
  final bool autoStartMonitor;

  const MainNavigation({
    super.key,
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
    if (_isInitialized) {
      return;
    }

    // Initialize data manager
    final dataManager = ref.read(timeSeriesDataManagerProvider);
    dataManager.startTracking();

    // Start listening to connection manager data streams
    await dataManager.startListening();

    _isInitialized = true;

    // Load settings after widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();

      // Auto-start spoofing if enabled
      _autoStartSpoofingIfEnabled();
    });
  }

  void _loadSettings() {
    final connectionActions = ref.read(connectionActionsProvider);
    connectionActions.loadConnectionSettings();

    final settingsManager = ref.read(settingsManagerProvider);
    final settings = settingsManager.settings;
    ref.read(selectedViewIndexProvider.notifier).state =
        settings.navigation.selectedViewIndex;
    ref.read(selectedPlotIndexProvider.notifier).state =
        settings.navigation.selectedPlotIndex;
  }

  void _autoStartSpoofingIfEnabled() {
    final settingsManager = ref.read(settingsManagerProvider);
    final settings = settingsManager.settings;

    if (settings.connection.enableSpoofing) {
      // Auto-start spoofing if enabled in settings
      final connectionActions = ref.read(connectionActionsProvider);
      connectionActions.connectWith(
        SpoofConnectionConfig(
          systemId: settings.connection.spoofSystemId,
          componentId: settings.connection.spoofComponentId,
          baudRate: settings.connection.spoofBaudRate,
        ),
      );
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
      children: const [
        JetsharkDashboard(),
        RealtimeDataDisplay(),
        MapView(),
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
        BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
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
