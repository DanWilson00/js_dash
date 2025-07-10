import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../telemetry/realtime_data_display.dart';
import '../dashboard/jetshark_dashboard.dart';
import '../map/map_view.dart';
import '../../providers/service_providers.dart';
import '../../providers/ui_providers.dart';
import '../../providers/action_providers.dart';
import '../../interfaces/i_connection_manager.dart';
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
    final connectionStatus = ref.watch(connectionStatusProvider);
    final errorState = ref.watch(errorStateProvider);
    final isLoading = ref.watch(isLoadingProvider);

    return Scaffold(
      body: _buildBody(selectedIndex),
      bottomNavigationBar: _buildBottomNavigation(selectedIndex, isConnected),
      floatingActionButton: _buildStatusIndicator(connectionStatus, errorState, isLoading),
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

  Widget _buildStatusIndicator(
    AsyncValue<ConnectionStatus> connectionStatus,
    String? errorState,
    bool isLoading,
  ) {
    if (isLoading) {
      return FloatingActionButton(
        onPressed: null,
        child: const CircularProgressIndicator(color: Colors.white),
      );
    }

    if (errorState != null) {
      return FloatingActionButton(
        onPressed: () => _showErrorDialog(errorState),
        backgroundColor: Colors.red,
        child: const Icon(Icons.error),
      );
    }

    return connectionStatus.when(
      data: (status) => FloatingActionButton(
        onPressed: _showConnectionDialog,
        backgroundColor: _getStatusColor(status.state),
        child: _getStatusIcon(status.state),
      ),
      loading: () => FloatingActionButton(
        onPressed: null,
        child: const CircularProgressIndicator(color: Colors.white),
      ),
      error: (error, stack) => FloatingActionButton(
        onPressed: () => _showErrorDialog(error.toString()),
        backgroundColor: Colors.red,
        child: const Icon(Icons.error),
      ),
    );
  }

  Color _getStatusColor(ConnectionState state) {
    return switch (state) {
      ConnectionState.connected => Colors.green,
      ConnectionState.connecting => Colors.orange,
      ConnectionState.paused => Colors.yellow,
      ConnectionState.error => Colors.red,
      ConnectionState.disconnected => Colors.grey,
    };
  }

  Widget _getStatusIcon(ConnectionState state) {
    return switch (state) {
      ConnectionState.connected => const Icon(Icons.wifi),
      ConnectionState.connecting => const Icon(Icons.wifi_find),
      ConnectionState.paused => const Icon(Icons.pause),
      ConnectionState.error => const Icon(Icons.wifi_off),
      ConnectionState.disconnected => const Icon(Icons.wifi_off),
    };
  }

  void _showConnectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection'),
        content: Consumer(
          builder: (context, ref, child) {
            final status = ref.watch(connectionStatusProvider);
            return status.when(
              data: (status) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: ${status.message}'),
                  const SizedBox(height: 8),
                  Text('State: ${status.state.name}'),
                  if (status.errorDetails != null) ...[
                    const SizedBox(height: 8),
                    Text('Error: ${status.errorDetails}'),
                  ],
                ],
              ),
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Error: $error'),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: _showConnectionSettings,
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  void _showConnectionSettings() {
    Navigator.of(context).pop(); // Close current dialog
    // TODO: Navigate to connection settings
    // This would typically show a connection settings dialog or page
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(navigationActionsProvider).clearError();
            },
            child: const Text('OK'),
          ),
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