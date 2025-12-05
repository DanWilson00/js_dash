import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connection_manager.dart';
import '../services/mavlink_message_tracker.dart';
import '../services/settings_manager.dart';
import '../services/timeseries_data_manager.dart';
import '../interfaces/i_data_source.dart';
import '../core/connection_status.dart';

/// Settings Manager Provider
final settingsManagerProvider = ChangeNotifierProvider<SettingsManager>((ref) {
  return SettingsManager();
});

/// Mavlink Message Tracker Provider
final mavlinkMessageTrackerProvider = Provider<MavlinkMessageTracker>((ref) {
  return MavlinkMessageTracker();
});

/// Connection Manager Provider
final connectionManagerProvider = Provider<ConnectionManager>((ref) {
  final tracker = ref.watch(mavlinkMessageTrackerProvider);
  final manager = ConnectionManager.injected(tracker);
  ref.onDispose(() => manager.dispose());
  return manager;
});

/// Time Series Data Manager Provider
/// This is the primary data repository for telemetry data
final timeSeriesDataManagerProvider = Provider<TimeSeriesDataManager>((ref) {
  final tracker = ref.watch(mavlinkMessageTrackerProvider);
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
