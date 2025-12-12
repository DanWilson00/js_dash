import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/connection_config.dart';
import '../models/app_settings.dart';
import '../models/plot_configuration.dart';
import 'service_providers.dart';

/// UI-specific providers that handle state for different UI components
/// These providers bridge between the service layer and UI widgets

// =============================================================================
// Navigation State
// =============================================================================

/// Notifier for selected view index
class SelectedViewIndexNotifier extends Notifier<int> {
  @override
  int build() {
    final settingsManager = ref.read(settingsManagerProvider);
    return settingsManager.settings.navigation.selectedViewIndex;
  }

  void set(int index) {
    state = index;
  }
}

/// Navigation State Provider - Manages which page/view is currently selected
final selectedViewIndexProvider =
    NotifierProvider<SelectedViewIndexNotifier, int>(
  SelectedViewIndexNotifier.new,
);

/// Notifier for selected plot index
class SelectedPlotIndexNotifier extends Notifier<int> {
  @override
  int build() {
    final settingsManager = ref.read(settingsManagerProvider);
    return settingsManager.settings.navigation.selectedPlotIndex;
  }

  void set(int index) {
    state = index;
  }
}

/// Plot Selection Provider - Manages which plot is currently selected
final selectedPlotIndexProvider =
    NotifierProvider<SelectedPlotIndexNotifier, int>(
  SelectedPlotIndexNotifier.new,
);

// =============================================================================
// Connection Configuration
// =============================================================================

/// Notifier for current connection config
class CurrentConnectionConfigNotifier extends Notifier<ConnectionConfig?> {
  @override
  ConnectionConfig? build() => null;

  void set(ConnectionConfig? config) {
    state = config;
  }
}

/// Connection Configuration Provider - Manages the current connection config
final currentConnectionConfigProvider =
    NotifierProvider<CurrentConnectionConfigNotifier, ConnectionConfig?>(
  CurrentConnectionConfigNotifier.new,
);

// =============================================================================
// Connection Form State
// =============================================================================

/// Connection form state
class ConnectionFormState {
  final String serialPort;
  final int serialBaudRate;
  final bool enableSpoofing;
  final int spoofSystemId;
  final int spoofComponentId;
  final int spoofBaudRate;
  final bool isValid;

  const ConnectionFormState({
    this.serialPort = '',
    this.serialBaudRate = 115200,
    this.enableSpoofing = false,
    this.spoofSystemId = 1,
    this.spoofComponentId = 1,
    this.spoofBaudRate = 57600,
    this.isValid = true,
  });

  ConnectionFormState copyWith({
    String? serialPort,
    int? serialBaudRate,
    bool? enableSpoofing,
    int? spoofSystemId,
    int? spoofComponentId,
    int? spoofBaudRate,
    bool? isValid,
  }) {
    return ConnectionFormState(
      serialPort: serialPort ?? this.serialPort,
      serialBaudRate: serialBaudRate ?? this.serialBaudRate,
      enableSpoofing: enableSpoofing ?? this.enableSpoofing,
      spoofSystemId: spoofSystemId ?? this.spoofSystemId,
      spoofComponentId: spoofComponentId ?? this.spoofComponentId,
      spoofBaudRate: spoofBaudRate ?? this.spoofBaudRate,
      isValid: isValid ?? this.isValid,
    );
  }

  /// Create connection config from current form state
  ConnectionConfig createConnectionConfig() {
    if (enableSpoofing) {
      return ConnectionConfigFactory.spoof(
        systemId: spoofSystemId,
        componentId: spoofComponentId,
        baudRate: spoofBaudRate,
      );
    }

    return ConnectionConfigFactory.serial(
      port: serialPort,
      baudRate: serialBaudRate,
    );
  }
}

/// Connection form state notifier (migrated from StateNotifier to Notifier)
class ConnectionFormNotifier extends Notifier<ConnectionFormState> {
  @override
  ConnectionFormState build() => const ConnectionFormState();

  void updateSerialPort(String port) {
    state = state.copyWith(serialPort: port);
    _validateForm();
  }

  void updateSerialBaudRate(int baudRate) {
    state = state.copyWith(serialBaudRate: baudRate);
    _validateForm();
  }

  void updateEnableSpoofing(bool enable) {
    state = state.copyWith(enableSpoofing: enable);
    _validateForm();
  }

  void updateSpoofSystemId(int systemId) {
    state = state.copyWith(spoofSystemId: systemId);
    _validateForm();
  }

  void updateSpoofComponentId(int componentId) {
    state = state.copyWith(spoofComponentId: componentId);
    _validateForm();
  }

  void updateSpoofBaudRate(int baudRate) {
    state = state.copyWith(spoofBaudRate: baudRate);
    _validateForm();
  }

  void _validateForm() {
    bool isValid = true;

    if (state.enableSpoofing) {
      // Spoof validation
      isValid = state.spoofSystemId > 0 &&
          state.spoofComponentId > 0 &&
          state.spoofBaudRate > 0;
    } else {
      // Serial connection validation
      isValid = state.serialPort.isNotEmpty && state.serialBaudRate > 0;
    }

    state = state.copyWith(isValid: isValid);
  }

  void loadFromSettings(AppSettings settings) {
    final conn = settings.connection;
    state = ConnectionFormState(
      serialPort: conn.serialPort,
      serialBaudRate: conn.serialBaudRate,
      enableSpoofing: conn.enableSpoofing,
      spoofSystemId: conn.spoofSystemId,
      spoofComponentId: conn.spoofComponentId,
      spoofBaudRate: conn.spoofBaudRate,
    );
    _validateForm();
  }
}

/// Connection Form State Provider
final connectionFormProvider =
    NotifierProvider<ConnectionFormNotifier, ConnectionFormState>(
  ConnectionFormNotifier.new,
);

// =============================================================================
// Settings Providers
// =============================================================================

/// Settings State Provider - Provides reactive access to app settings
final appSettingsProvider = StreamProvider<AppSettings>((ref) async* {
  final settingsManager = ref.watch(settingsManagerProvider);
  yield settingsManager.settings;
});

/// Window Settings Provider
final windowSettingsProvider = Provider<WindowSettings>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.when(
    data: (settings) => settings.window,
    loading: () => WindowSettings.defaults(),
    error: (e, s) => WindowSettings.defaults(),
  );
});

/// Plot Settings Provider
final plotSettingsProvider = Provider<PlotSettings>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.when(
    data: (settings) => settings.plots,
    loading: () => PlotSettings.defaults(),
    error: (e, s) => PlotSettings.defaults(),
  );
});

/// Performance Settings Provider
final performanceSettingsProvider = Provider<PerformanceSettings>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.when(
    data: (settings) => settings.performance,
    loading: () => PerformanceSettings.defaults(),
    error: (e, s) => PerformanceSettings.defaults(),
  );
});

/// Map Settings Provider
final mapSettingsProvider = Provider<MapSettings>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.when(
    data: (settings) => settings.map,
    loading: () => MapSettings.defaults(),
    error: (e, s) => MapSettings.defaults(),
  );
});

/// Theme Provider
final themeProvider = Provider<ThemeData>((ref) {
  return ThemeData.dark().copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
    visualDensity: VisualDensity.compact,
  );
});

// =============================================================================
// Field Selection
// =============================================================================

/// Notifier for selected fields
class SelectedFieldsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void set(Set<String> fields) {
    state = fields;
  }

  void add(String field) {
    state = {...state, field};
  }

  void remove(String field) {
    state = {...state}..remove(field);
  }

  void toggle(String field) {
    if (state.contains(field)) {
      remove(field);
    } else {
      add(field);
    }
  }

  void clear() {
    state = <String>{};
  }
}

/// Field Selection Provider - Manages which fields are selected for plotting
final selectedFieldsProvider =
    NotifierProvider<SelectedFieldsNotifier, Set<String>>(
  SelectedFieldsNotifier.new,
);

// =============================================================================
// Plot Configuration (Family Provider)
// =============================================================================

/// Plot Configuration Provider for specific plot index
/// Uses a simple Provider.family since this is derived from other state
final plotConfigurationProvider = Provider.family<PlotConfiguration?, int>(
  (ref, plotIndex) {
    final plotSettings = ref.watch(plotSettingsProvider);
    // Find current tab
    final tab = plotSettings.tabs.firstWhere(
      (t) => t.id == plotSettings.selectedTabId,
      orElse: () => plotSettings.tabs.first,
    );

    if (plotIndex >= 0 && plotIndex < tab.plots.length) {
      return tab.plots[plotIndex];
    }
    return null;
  },
);

// =============================================================================
// Global UI State
// =============================================================================

/// Notifier for pause state
class IsPausedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    state = value;
  }

  void toggle() {
    state = !state;
  }
}

/// Pause State Provider - Manages global pause state for data collection
final isPausedProvider = NotifierProvider<IsPausedNotifier, bool>(
  IsPausedNotifier.new,
);

/// Notifier for error state
class ErrorStateNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? error) {
    state = error;
  }

  void clear() {
    state = null;
  }
}

/// Error State Provider - Manages global error state and messages
final errorStateProvider = NotifierProvider<ErrorStateNotifier, String?>(
  ErrorStateNotifier.new,
);

/// Notifier for loading state
class IsLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    state = value;
  }
}

/// Loading State Provider - Manages global loading state
final isLoadingProvider = NotifierProvider<IsLoadingNotifier, bool>(
  IsLoadingNotifier.new,
);
