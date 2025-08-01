import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/service_locator.dart';
import '../interfaces/i_connection_manager.dart';
import '../interfaces/i_data_repository.dart';
import '../interfaces/i_data_source.dart';
import '../services/connection_manager.dart';
import '../services/telemetry_repository.dart';
import '../services/settings_manager.dart';

/// Core service providers using Riverpod
/// These providers manage the lifecycle of our core services and provide
/// them to the widget tree with proper dependency injection

/// Connection Manager Provider
/// Manages MAVLink connections (UDP/Serial/Spoof)
final connectionManagerProvider = Provider<IConnectionManager>((ref) {
  // Try to get from service locator first, fallback to direct instantiation
  try {
    return GetIt.get<ConnectionManager>();
  } catch (e) {
    final manager = ConnectionManager.injected();
    // Register in service locator for future use
    GetIt.registerSingleton<ConnectionManager>(manager);
    return manager;
  }
});

/// Telemetry Repository Provider
/// Provides unified access to all telemetry data
final telemetryRepositoryProvider = Provider<IDataRepository>((ref) {
  // Get connection manager from provider
  final connectionManager = ref.read(connectionManagerProvider) as ConnectionManager;
  
  // Try to get from service locator first
  try {
    return GetIt.get<TelemetryRepository>();
  } catch (e) {
    final repository = TelemetryRepository.injected(
      connectionManager: connectionManager,
    );
    // Register in service locator for future use
    GetIt.registerSingleton<TelemetryRepository>(repository);
    return repository;
  }
});

/// Settings Manager Provider
/// Manages application settings and preferences
final settingsManagerProvider = Provider<SettingsManager>((ref) {
  try {
    return GetIt.get<SettingsManager>();
  } catch (e) {
    final manager = SettingsManager();
    GetIt.registerSingleton<SettingsManager>(manager);
    return manager;
  }
});

/// Current Data Source Provider
/// Provides access to the currently active data source
final currentDataSourceProvider = Provider<IDataSource?>((ref) {
  final connectionManager = ref.watch(connectionManagerProvider) as ConnectionManager;
  return connectionManager.currentDataSource;
});

/// Connection Status Provider
/// Provides reactive connection status updates
final connectionStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  final connectionManager = ref.watch(connectionManagerProvider);
  return connectionManager.statusStream;
});

/// Telemetry Data Stream Provider
/// Provides reactive telemetry data updates
final telemetryDataProvider = StreamProvider((ref) {
  final repository = ref.watch(telemetryRepositoryProvider);
  return repository.dataStream;
});

/// Connection State Provider (convenience)
/// Provides just the connection state for UI widgets
final connectionStateProvider = Provider<ConnectionState>((ref) {
  final status = ref.watch(connectionStatusProvider);
  return status.when(
    data: (status) => status.state,
    loading: () => ConnectionState.disconnected,
    error: (_, __) => ConnectionState.error,
  );
});

/// Is Connected Provider (convenience)
/// Simple boolean for connection status
final isConnectedProvider = Provider<bool>((ref) {
  final state = ref.watch(connectionStateProvider);
  return state == ConnectionState.connected;
});

/// Available Fields Provider
/// Provides list of available telemetry fields
final availableFieldsProvider = Provider<List<String>>((ref) {
  final repository = ref.watch(telemetryRepositoryProvider);
  return repository.getAvailableFields();
});

/// Data Summary Provider
/// Provides summary of current data buffers
final dataSummaryProvider = Provider<Map<String, int>>((ref) {
  final repository = ref.watch(telemetryRepositoryProvider);
  return repository.getDataSummary();
});

/// Provider lifecycle management
/// Call this to dispose of providers when app shuts down
void disposeProviders() {
  // Dispose services if they implement Disposable
  try {
    final connectionManager = GetIt.get<ConnectionManager>();
    connectionManager.dispose();
  } catch (e) {
    // Service not registered
  }

  try {
    final repository = GetIt.get<TelemetryRepository>();
    repository.dispose();
  } catch (e) {
    // Service not registered
  }

  try {
    final settingsManager = GetIt.get<SettingsManager>();
    settingsManager.dispose();
  } catch (e) {
    // Service not registered
  }

  // Reset service locator
  GetIt.reset();
}