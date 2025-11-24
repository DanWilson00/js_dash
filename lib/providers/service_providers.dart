import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connection_manager.dart';
import '../services/mavlink_message_tracker.dart';
import '../services/settings_manager.dart';
import '../services/telemetry_repository.dart';
import '../services/timeseries_data_manager.dart';
import '../interfaces/i_data_source.dart';
import '../core/connection_status.dart';

/// Settings Manager Provider
final settingsManagerProvider = Provider<SettingsManager>((ref) {
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
final timeSeriesDataManagerProvider = Provider<TimeSeriesDataManager>((ref) {
  final tracker = ref.watch(mavlinkMessageTrackerProvider);
  final settingsManager = ref.watch(settingsManagerProvider);
  final manager = TimeSeriesDataManager.injected(tracker, settingsManager);
  ref.onDispose(() => manager.dispose());
  return manager;
});

/// Telemetry Repository Provider
final telemetryRepositoryProvider = Provider<TelemetryRepository>((ref) {
  final connectionManager = ref.watch(connectionManagerProvider);
  final timeSeriesManager = ref.watch(timeSeriesDataManagerProvider);
  final repository = TelemetryRepository(
    connectionManager: connectionManager,
    timeSeriesManager: timeSeriesManager,
  );
  ref.onDispose(() => repository.dispose());
  return repository;
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
  final repository = ref.watch(telemetryRepositoryProvider);
  return repository.getAvailableFields();
});
