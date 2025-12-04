import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/connection_config.dart';
import '../interfaces/i_connection_manager.dart';
import '../interfaces/i_data_repository.dart';
import '../services/settings_manager.dart';
import 'service_providers.dart';
import 'ui_providers.dart';

/// Action providers handle common operations and business logic
/// These providers encapsulate actions that can be called from UI components

/// Connection Actions Provider
/// Handles connection-related operations
final connectionActionsProvider = Provider<ConnectionActions>((ref) {
  final connectionManager = ref.read(connectionManagerProvider);
  final settingsManager = ref.read(settingsManagerProvider);
  return ConnectionActions(connectionManager, settingsManager, ref);
});

class ConnectionActions {
  final IConnectionManager _connectionManager;
  final SettingsManager _settingsManager;
  final Ref _ref;

  ConnectionActions(this._connectionManager, this._settingsManager, this._ref);

  /// Connect using the current form configuration
  Future<bool> connectWithCurrentConfig() async {
    final formState = _ref.read(connectionFormProvider);
    if (!formState.isValid) return false;

    _ref.read(isLoadingProvider.notifier).state = true;
    _ref.read(errorStateProvider.notifier).state = null;

    try {
      final config = formState.createConnectionConfig();
      final success = await _connectionManager.connect(config);
      
      if (success) {
        // Save successful connection settings
        await _saveConnectionSettings(formState);
        _ref.read(currentConnectionConfigProvider.notifier).state = config;
      } else {
        _ref.read(errorStateProvider.notifier).state = 'Failed to connect';
      }

      return success;
    } catch (e) {
      _ref.read(errorStateProvider.notifier).state = 'Connection error: $e';
      return false;
    } finally {
      _ref.read(isLoadingProvider.notifier).state = false;
    }
  }

  /// Disconnect from current connection
  Future<void> disconnect() async {
    _ref.read(isLoadingProvider.notifier).state = true;
    _ref.read(errorStateProvider.notifier).state = null;

    try {
      await _connectionManager.disconnect();
      _ref.read(currentConnectionConfigProvider.notifier).state = null;
    } catch (e) {
      _ref.read(errorStateProvider.notifier).state = 'Disconnect error: $e';
    } finally {
      _ref.read(isLoadingProvider.notifier).state = false;
    }
  }

  /// Pause connection
  void pause() {
    try {
      _connectionManager.pause();
      _ref.read(isPausedProvider.notifier).state = true;
    } catch (e) {
      _ref.read(errorStateProvider.notifier).state = 'Pause error: $e';
    }
  }

  /// Resume connection
  void resume() {
    try {
      _connectionManager.resume();
      _ref.read(isPausedProvider.notifier).state = false;
    } catch (e) {
      _ref.read(errorStateProvider.notifier).state = 'Resume error: $e';
    }
  }

  /// Connect with specific configuration
  Future<bool> connectWith(ConnectionConfig config) async {
    _ref.read(isLoadingProvider.notifier).state = true;
    _ref.read(errorStateProvider.notifier).state = null;

    try {
      final success = await _connectionManager.connect(config);
      
      if (success) {
        _ref.read(currentConnectionConfigProvider.notifier).state = config;
      } else {
        _ref.read(errorStateProvider.notifier).state = 'Failed to connect';
      }

      return success;
    } catch (e) {
      _ref.read(errorStateProvider.notifier).state = 'Connection error: $e';
      return false;
    } finally {
      _ref.read(isLoadingProvider.notifier).state = false;
    }
  }

  /// Load connection settings from stored configuration
  void loadConnectionSettings() {
    final formNotifier = _ref.read(connectionFormProvider.notifier);
    formNotifier.loadFromSettings(_settingsManager.settings);
  }

  /// Save connection settings
  Future<void> _saveConnectionSettings(ConnectionFormState formState) async {
    _settingsManager.updateConnectionMode(formState.enableSpoofing);

    if (!formState.enableSpoofing) {
      _settingsManager.updateSerialConnection(formState.serialPort, formState.serialBaudRate);
    } else {
      _settingsManager.updateSpoofingConfig(
        spoofBaudRate: formState.spoofBaudRate,
        spoofSystemId: formState.spoofSystemId,
        spoofComponentId: formState.spoofComponentId,
      );
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
      _ref.read(errorStateProvider.notifier).state = null;
    } catch (e) {
      _ref.read(errorStateProvider.notifier).state = 'Error clearing data: $e';
    }
  }

  /// Pause data collection
  void pauseDataCollection() {
    try {
      _repository.pause();
      _ref.read(isPausedProvider.notifier).state = true;
    } catch (e) {
      _ref.read(errorStateProvider.notifier).state = 'Error pausing data: $e';
    }
  }

  /// Resume data collection
  void resumeDataCollection() {
    try {
      _repository.resume();
      _ref.read(isPausedProvider.notifier).state = false;
    } catch (e) {
      _ref.read(errorStateProvider.notifier).state = 'Error resuming data: $e';
    }
  }

  /// Get field data for plotting
  List<dynamic> getFieldData(String messageType, String fieldName) {
    try {
      return _repository.getFieldData(messageType, fieldName);
    } catch (e) {
      _ref.read(errorStateProvider.notifier).state = 'Error getting field data: $e';
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
    
    _ref.read(selectedFieldsProvider.notifier).state = newSelection;
  }

  /// Select multiple fields
  void selectFields(Set<String> fields) {
    _ref.read(selectedFieldsProvider.notifier).state = fields;
  }

  /// Clear field selection
  void clearFieldSelection() {
    _ref.read(selectedFieldsProvider.notifier).state = <String>{};
  }
}

/// Navigation Actions Provider
/// Handles navigation and UI state changes
final navigationActionsProvider = Provider<NavigationActions>((ref) {
  final settingsManager = ref.read(settingsManagerProvider);
  return NavigationActions(settingsManager, ref);
});

class NavigationActions {
  final SettingsManager _settingsManager;
  final Ref _ref;

  NavigationActions(this._settingsManager, this._ref);

  /// Navigate to specific view
  void navigateToView(int viewIndex) {
    _ref.read(selectedViewIndexProvider.notifier).state = viewIndex;
    _settingsManager.updateSelectedViewIndex(viewIndex);
  }

  /// Select specific plot
  void selectPlot(int plotIndex) {
    _ref.read(selectedPlotIndexProvider.notifier).state = plotIndex;
    _settingsManager.updateSelectedPlotInNavigation(plotIndex);
  }

  /// Clear any error state
  void clearError() {
    _ref.read(errorStateProvider.notifier).state = null;
  }

  /// Show error message
  void showError(String error) {
    _ref.read(errorStateProvider.notifier).state = error;
  }

  /// Set loading state
  void setLoading(bool loading) {
    _ref.read(isLoadingProvider.notifier).state = loading;
  }
}