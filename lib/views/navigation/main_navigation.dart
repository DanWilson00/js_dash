import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../telemetry/realtime_data_display.dart';
import '../dashboard/main_dashboard.dart';
import '../map/map_view.dart';
import '../../models/app_settings.dart';
import '../../providers/service_providers.dart';
import '../../providers/ui_providers.dart';
import '../../providers/action_providers.dart';
import '../../core/connection_config.dart';
import '../../services/serial/serial_service.dart';

class MainNavigation extends ConsumerStatefulWidget {
  final bool autoStartMonitor;

  const MainNavigation({super.key, this.autoStartMonitor = true});

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

    final settings = ref.read(settingsProvider).value ?? AppSettings.defaults();
    ref
        .read(selectedViewIndexProvider.notifier)
        .set(settings.navigation.selectedViewIndex);
    ref
        .read(selectedPlotIndexProvider.notifier)
        .set(settings.navigation.selectedPlotIndex);
  }

  void _autoStartConnectionIfEnabled() {
    final settings = ref.read(settingsProvider).value ?? AppSettings.defaults();
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
      final availablePorts = getAvailableSerialPorts();
      final portExists = availablePorts.any(
        (p) => p.portName == settings.connection.serialPort,
      );
      if (portExists) {
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
      children: [
        MainDashboard(isActive: selectedIndex == 0),
        const RealtimeDataDisplay(),
        MapView(isActive: selectedIndex == 2),
      ],
    );
  }

  Widget _buildBottomNavigation(int selectedIndex, bool isConnected) {
    final selectedColor = isConnected ? Colors.green : Colors.blue;

    Widget buildItem(int index, IconData icon, String label) {
      final isSelected = selectedIndex == index;
      return Expanded(
        child: InkWell(
          onTap: () => _onItemTapped(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected ? selectedColor : Colors.grey,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? selectedColor : Colors.grey,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          buildItem(0, Icons.dashboard, 'Dashboard'),
          buildItem(1, Icons.show_chart, 'Telemetry'),
          buildItem(2, Icons.map, 'Map'),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Clean up is handled by providers automatically
    super.dispose();
  }
}
