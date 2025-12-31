import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/connection_config.dart';
import '../interfaces/i_connection_manager.dart';
import '../interfaces/i_data_repository.dart';
import '../models/app_settings.dart';
import '../services/dialect_discovery.dart';
import 'service_providers.dart';
import 'ui_providers.dart';

/// Action providers handle common operations and business logic
/// These providers encapsulate actions that can be called from UI components

/// Connection Actions Provider
/// Handles connection-related operations
final connectionActionsProvider = Provider<ConnectionActions>((ref) {
  final settings = ref.read(settingsProvider.notifier);
  return ConnectionActions(settings, ref);
});

class ConnectionActions {
  final Settings _settings;
  final Ref _ref;

  ConnectionActions(this._settings, this._ref);

  /// Get the current connection manager (always fresh to avoid stale references after invalidation)
  IConnectionManager get _connectionManager => _ref.read(connectionManagerProvider);

  /// Connect using the current form configuration
  Future<bool> connectWithCurrentConfig() async {
    final formState = _ref.read(connectionFormProvider);
    if (!formState.isValid) return false;

    _ref.read(isLoadingProvider.notifier).set(true);
    _ref.read(errorStateProvider.notifier).set(null);

    try {
      final config = formState.createConnectionConfig();
      final success = await _connectionManager.connect(config);
      
      if (success) {
        // Save successful connection settings
        await _saveConnectionSettings(formState);
        _ref.read(currentConnectionConfigProvider.notifier).set(config);
      } else {
        _ref.read(errorStateProvider.notifier).set('Failed to connect');
      }

      return success;
    } catch (e) {
      _ref.read(errorStateProvider.notifier).set('Connection error: $e');
      return false;
    } finally {
      _ref.read(isLoadingProvider.notifier).set(false);
    }
  }

  /// Disconnect from current connection
  Future<void> disconnect() async {
    _ref.read(isLoadingProvider.notifier).set(true);
    _ref.read(errorStateProvider.notifier).set(null);

    try {
      await _connectionManager.disconnect();
      _ref.read(currentConnectionConfigProvider.notifier).set(null);
    } catch (e) {
      _ref.read(errorStateProvider.notifier).set('Disconnect error: $e');
    } finally {
      _ref.read(isLoadingProvider.notifier).set(false);
    }
  }

  /// Pause connection
  void pause() {
    try {
      _connectionManager.pause();
      _ref.read(isPausedProvider.notifier).set(true);
    } catch (e) {
      _ref.read(errorStateProvider.notifier).set('Pause error: $e');
    }
  }

  /// Resume connection
  void resume() {
    try {
      _connectionManager.resume();
      _ref.read(isPausedProvider.notifier).set(false);
    } catch (e) {
      _ref.read(errorStateProvider.notifier).set('Resume error: $e');
    }
  }

  /// Connect with specific configuration
  Future<bool> connectWith(ConnectionConfig config) async {
    _ref.read(isLoadingProvider.notifier).set(true);
    _ref.read(errorStateProvider.notifier).set(null);

    try {
      final success = await _connectionManager.connect(config);
      
      if (success) {
        _ref.read(currentConnectionConfigProvider.notifier).set(config);
      } else {
        _ref.read(errorStateProvider.notifier).set('Failed to connect');
      }

      return success;
    } catch (e) {
      _ref.read(errorStateProvider.notifier).set('Connection error: $e');
      return false;
    } finally {
      _ref.read(isLoadingProvider.notifier).set(false);
    }
  }

  /// Load connection settings from stored configuration
  void loadConnectionSettings() {
    final formNotifier = _ref.read(connectionFormProvider.notifier);
    final appSettings = _ref.read(settingsProvider).value ?? AppSettings.defaults();
    formNotifier.loadFromSettings(appSettings);
  }

  /// Save connection settings
  Future<void> _saveConnectionSettings(ConnectionFormState formState) async {
    _settings.updateConnectionMode(formState.enableSpoofing);

    if (!formState.enableSpoofing) {
      _settings.updateSerialConnection(formState.serialPort, formState.serialBaudRate);
    } else {
      _settings.updateSpoofingConfig(
        spoofBaudRate: formState.spoofBaudRate,
        spoofSystemId: formState.spoofSystemId,
        spoofComponentId: formState.spoofComponentId,
      );
    }
  }

  /// Change MAVLink dialect
  ///
  /// Saves the dialect setting. Requires app restart to take effect.
  /// Returns true if the dialect was changed (restart needed).
  bool changeDialect(String newDialect) {
    final currentDialect = _settings.connection.mavlinkDialect;
    if (newDialect == currentDialect) return false;

    _settings.updateMavlinkDialect(newDialect);
    return true; // Restart required
  }

  /// Connect with spoofing configuration from settings
  Future<bool> connectWithSpoofing() async {
    final connectionSettings = _settings.connection;
    final config = SpoofConnectionConfig(
      systemId: connectionSettings.spoofSystemId,
      componentId: connectionSettings.spoofComponentId,
    );
    return await connectWith(config);
  }

  /// Import an XML dialect file
  ///
  /// Parses the XML file, generates JSON metadata, saves it to user dialects
  /// folder, and sets it as the current dialect. Requires app restart.
  /// Returns the imported dialect name.
  Future<String> importXmlDialect(String xmlPath) async {
    _ref.read(isLoadingProvider.notifier).set(true);
    _ref.read(errorStateProvider.notifier).set(null);

    try {
      // Import and generate JSON from XML
      final userDialectManager = DialectDiscovery.userDialectManager;
      final dialectName = await userDialectManager.importXmlDialect(xmlPath);

      // Set as current dialect (will be loaded on restart)
      _settings.updateMavlinkDialect(dialectName);

      return dialectName;
    } catch (e) {
      _ref.read(errorStateProvider.notifier).set('Error importing dialect: $e');
      rethrow;
    } finally {
      _ref.read(isLoadingProvider.notifier).set(false);
    }
  }

  /// Reload a user dialect from its original XML source
  ///
  /// Re-parses the XML and regenerates the JSON. Requires app restart.
  Future<void> reloadUserDialect(String dialectName) async {
    _ref.read(isLoadingProvider.notifier).set(true);
    _ref.read(errorStateProvider.notifier).set(null);

    try {
      // Reload from XML (regenerates JSON)
      final userDialectManager = DialectDiscovery.userDialectManager;
      await userDialectManager.reloadDialect(dialectName);
      // Restart required for changes to take effect
    } catch (e) {
      _ref.read(errorStateProvider.notifier).set('Error reloading dialect: $e');
      rethrow;
    } finally {
      _ref.read(isLoadingProvider.notifier).set(false);
    }
  }
}

/// Data Actions Provider
/// Handles data-related operations
final dataActionsProvider = Provider<DataActions>((ref) {
  final dataManager = ref.read(timeSeriesDataManagerProvider);
  return DataActions(dataManager, ref);
});

class DataActions {
  final IDataRepository _repository;
  final Ref _ref;

  DataActions(this._repository, this._ref);

  /// Clear all telemetry data
  void clearAllData() {
    try {
      _repository.clearAllData();
      _ref.read(errorStateProvider.notifier).set(null);
    } catch (e) {
      _ref.read(errorStateProvider.notifier).set('Error clearing data: $e');
    }
  }

  /// Pause data collection
  void pauseDataCollection() {
    try {
      _repository.pause();
      _ref.read(isPausedProvider.notifier).set(true);
    } catch (e) {
      _ref.read(errorStateProvider.notifier).set('Error pausing data: $e');
    }
  }

  /// Resume data collection
  void resumeDataCollection() {
    try {
      _repository.resume();
      _ref.read(isPausedProvider.notifier).set(false);
    } catch (e) {
      _ref.read(errorStateProvider.notifier).set('Error resuming data: $e');
    }
  }

  /// Get field data for plotting
  List<dynamic> getFieldData(String messageType, String fieldName) {
    try {
      return _repository.getFieldData(messageType, fieldName);
    } catch (e) {
      _ref.read(errorStateProvider.notifier).set('Error getting field data: $e');
      return [];
    }
  }

  /// Toggle field selection for plotting
  void toggleFieldSelection(String fieldName) {
    final currentSelection = _ref.read(selectedFieldsProvider);
    final newSelection = Set<String>.from(currentSelection);
    
    if (newSelection.contains(fieldName)) {
      newSelection.remove(fieldName);
    } else {
      newSelection.add(fieldName);
    }
    
    _ref.read(selectedFieldsProvider.notifier).set(newSelection);
  }

  /// Select multiple fields
  void selectFields(Set<String> fields) {
    _ref.read(selectedFieldsProvider.notifier).set(fields);
  }

  /// Clear field selection
  void clearFieldSelection() {
    _ref.read(selectedFieldsProvider.notifier).clear();
  }
}

/// Navigation Actions Provider
/// Handles navigation and UI state changes
final navigationActionsProvider = Provider<NavigationActions>((ref) {
  final settings = ref.read(settingsProvider.notifier);
  return NavigationActions(settings, ref);
});

class NavigationActions {
  final Settings _settings;
  final Ref _ref;

  NavigationActions(this._settings, this._ref);

  /// Navigate to specific view
  void navigateToView(int viewIndex) {
    _ref.read(selectedViewIndexProvider.notifier).set(viewIndex);
    _settings.updateSelectedViewIndex(viewIndex);
  }

  /// Select specific plot
  void selectPlot(int plotIndex) {
    _ref.read(selectedPlotIndexProvider.notifier).set(plotIndex);
    _settings.updateSelectedPlotInNavigation(plotIndex);
  }

  /// Clear any error state
  void clearError() {
    _ref.read(errorStateProvider.notifier).set(null);
  }

  /// Show error message
  void showError(String error) {
    _ref.read(errorStateProvider.notifier).set(error);
  }

  /// Set loading state
  void setLoading(bool loading) {
    _ref.read(isLoadingProvider.notifier).set(loading);
  }
}