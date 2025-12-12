import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../telemetry/realtime_data_display.dart';
import '../dashboard/jetshark_dashboard.dart';
import '../map/map_view.dart';
import '../../providers/service_providers.dart';
import '../../providers/ui_providers.dart';
import '../../providers/action_providers.dart';
import '../../core/connection_config.dart';
import '../../services/serial_byte_source.dart';

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

      // Auto-start connection if configured
      _autoStartConnectionIfEnabled();
    });
  }

  void _loadSettings() {
    final connectionActions = ref.read(connectionActionsProvider);
    connectionActions.loadConnectionSettings();

    final settingsManager = ref.read(settingsManagerProvider);
    final settings = settingsManager.settings;
    ref.read(selectedViewIndexProvider.notifier).set(
        settings.navigation.selectedViewIndex);
    ref.read(selectedPlotIndexProvider.notifier).set(
        settings.navigation.selectedPlotIndex);
  }

  void _autoStartConnectionIfEnabled() {
    final settingsManager = ref.read(settingsManagerProvider);
    final settings = settingsManager.settings;
    final connectionActions = ref.read(connectionActionsProvider);

    if (settings.connection.enableSpoofing) {
      // Auto-start spoofing if enabled in settings
      connectionActions.connectWith(
        SpoofConnectionConfig(
          systemId: settings.connection.spoofSystemId,
          componentId: settings.connection.spoofComponentId,
          baudRate: settings.connection.spoofBaudRate,
        ),
      );
    } else if (settings.connection.serialPort.isNotEmpty) {
      // Auto-start serial if spoofing disabled and port is configured
      // Only connect if the port actually exists
      final availablePorts = SerialByteSource.getAvailablePorts();
      if (availablePorts.contains(settings.connection.serialPort)) {
        connectionActions.connectWith(
          SerialConnectionConfig(
            port: settings.connection.serialPort,
            baudRate: settings.connection.serialBaudRate,
          ),
        );
      }
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
