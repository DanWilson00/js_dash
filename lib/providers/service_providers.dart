import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // For ChangeNotifierProvider

import '../core/connection_status.dart';
import '../interfaces/i_data_source.dart';
import '../mavlink/mavlink.dart';
import '../services/connection_manager.dart';
import '../services/generic_message_tracker.dart';
import '../services/platform/platform_capabilities.dart';
import '../services/settings_manager.dart';
import '../services/timeseries_data_manager.dart';

/// Platform Capabilities Provider
/// Provides platform detection for conditional features
final platformCapabilitiesProvider = Provider<PlatformCapabilities>((ref) {
  return PlatformCapabilities.instance;
});

/// MAVLink Metadata Registry Provider
/// This must be initialized before use by loading the JSON file
final mavlinkRegistryProvider = Provider<MavlinkMetadataRegistry>((ref) {
  return MavlinkMetadataRegistry();
});

/// Settings Manager Provider
/// SettingsManager is a ChangeNotifier - using ChangeNotifierProvider so
/// Riverpod properly rebuilds widgets when notifyListeners() is called.
final settingsManagerProvider = ChangeNotifierProvider<SettingsManager>((ref) {
  return SettingsManager();
});

/// Generic Message Tracker Provider
final messageTrackerProvider = Provider<GenericMessageTracker>((ref) {
  final registry = ref.watch(mavlinkRegistryProvider);
  return GenericMessageTracker(registry);
});

/// Connection Manager Provider
final connectionManagerProvider = Provider<ConnectionManager>((ref) {
  final registry = ref.watch(mavlinkRegistryProvider);
  final tracker = ref.watch(messageTrackerProvider);
  final manager = ConnectionManager.injected(registry, tracker);
  ref.onDispose(() => manager.dispose());
  return manager;
});

/// Time Series Data Manager Provider
/// This is the primary data repository for telemetry data
final timeSeriesDataManagerProvider = Provider<TimeSeriesDataManager>((ref) {
  final tracker = ref.watch(messageTrackerProvider);
  // Use read instead of watch to prevent rebuilding when settings change
  // The manager listens to settings changes internally
  final settingsManager = ref.read(settingsManagerProvider);
  final connectionManager = ref.watch(connectionManagerProvider);
  final manager = TimeSeriesDataManager.injected(
    tracker,
    settingsManager,
    connectionManager,
  );
  ref.onDispose(() => manager.dispose());
  return manager;
});

/// Current Data Source Provider
final currentDataSourceProvider = Provider<IDataSource?>((ref) {
  final connectionManager = ref.watch(connectionManagerProvider);
  return connectionManager.currentDataSource;
});

/// Connection Status Provider
final connectionStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  final connectionManager = ref.watch(connectionManagerProvider);
  return connectionManager.statusStream;
});

/// Connection State Provider (derived from status)
final connectionStateProvider = Provider<ConnectionState>((ref) {
  final statusAsync = ref.watch(connectionStatusProvider);
  return statusAsync.when(
    data: (status) => status.state,
    loading: () => ConnectionState.disconnected,
    error: (error, stackTrace) => ConnectionState.error,
  );
});

/// Is Connected Provider
final isConnectedProvider = Provider<bool>((ref) {
  final state = ref.watch(connectionStateProvider);
  return state == ConnectionState.connected;
});

/// Available Fields Provider
final availableFieldsProvider = Provider<List<String>>((ref) {
  final dataManager = ref.watch(timeSeriesDataManagerProvider);
  return dataManager.getAvailableFields();
});
