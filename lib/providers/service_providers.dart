import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connection_status.dart';
import '../interfaces/i_data_source.dart';
import '../mavlink/mavlink.dart';
import '../services/connection_manager.dart';
import '../services/generic_message_tracker.dart';
import '../services/platform/platform_capabilities.dart';
import '../services/settings_manager.dart';
import '../services/timeseries_data_manager.dart';

// Re-export settingsProvider from settings_manager.dart (generated)
export '../services/settings_manager.dart' show settingsProvider, Settings;

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
  // Get settings notifier for reading performance settings
  final settings = ref.read(settingsProvider.notifier);
  final connectionManager = ref.watch(connectionManagerProvider);
  final manager = TimeSeriesDataManager.injected(
    tracker,
    settings,
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
