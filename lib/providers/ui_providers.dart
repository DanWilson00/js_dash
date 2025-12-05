import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/connection_config.dart';
import '../models/app_settings.dart';
import '../models/plot_configuration.dart';
import 'service_providers.dart';

/// UI-specific providers that handle state for different UI components
/// These providers bridge between the service layer and UI widgets

/// Navigation State Provider
/// Manages which page/view is currently selected
final selectedViewIndexProvider = StateProvider<int>((ref) {
  final settingsManager = ref.read(settingsManagerProvider);
  return settingsManager.settings.navigation.selectedViewIndex;
});

/// Plot Selection Provider
/// Manages which plot is currently selected
final selectedPlotIndexProvider = StateProvider<int>((ref) {
  final settingsManager = ref.read(settingsManagerProvider);
  return settingsManager.settings.navigation.selectedPlotIndex;
});

/// Connection Configuration Provider
/// Manages the current connection configuration being edited
final currentConnectionConfigProvider = StateProvider<ConnectionConfig?>(
  (ref) => null,
);

/// Connection Form State Provider
/// Manages the state of connection form fields
final connectionFormProvider =
    StateNotifierProvider<ConnectionFormNotifier, ConnectionFormState>((ref) {
      return ConnectionFormNotifier();
    });

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

/// Connection form state notifier
class ConnectionFormNotifier extends StateNotifier<ConnectionFormState> {
  ConnectionFormNotifier() : super(const ConnectionFormState());

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
      isValid =
          state.spoofSystemId > 0 &&
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

/// Settings State Provider
/// Provides reactive access to app settings
final appSettingsProvider = StreamProvider<AppSettings>((ref) async* {
  final settingsManager = ref.watch(settingsManagerProvider);
  yield settingsManager.settings;
});

/// Window Settings Provider
/// Manages window size, position, etc.
final windowSettingsProvider = Provider<WindowSettings>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.when(
    data: (settings) => settings.window,
    loading: () => WindowSettings.defaults(),
    error: (e, s) => WindowSettings.defaults(),
  );
});

/// Plot Settings Provider
/// Manages plot configuration and layout
final plotSettingsProvider = Provider<PlotSettings>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.when(
    data: (settings) => settings.plots,
    loading: () => PlotSettings.defaults(),
    error: (e, s) => PlotSettings.defaults(),
  );
});

/// Performance Settings Provider
/// Manages performance and optimization settings
final performanceSettingsProvider = Provider<PerformanceSettings>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.when(
    data: (settings) => settings.performance,
    loading: () => PerformanceSettings.defaults(),
    error: (e, s) => PerformanceSettings.defaults(),
  );
});

/// Map Settings Provider
/// Manages map display and interaction settings
final mapSettingsProvider = Provider<MapSettings>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.when(
    data: (settings) => settings.map,
    loading: () => MapSettings.defaults(),
    error: (e, s) => MapSettings.defaults(),
  );
});

/// Theme Provider
/// Could be extended for theme management
final themeProvider = Provider<ThemeData>((ref) {
  // For now, return default dark theme suitable for dashboard
  return ThemeData.dark().copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
    visualDensity: VisualDensity.compact,
  );
});

/// Field Selection Provider
/// Manages which fields are selected for plotting
final selectedFieldsProvider = StateProvider<Set<String>>((ref) => <String>{});

/// Plot Configuration Provider for specific plot index
final plotConfigurationProvider = StateProvider.family<PlotConfiguration?, int>(
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

/// Pause State Provider
/// Manages global pause state for data collection
final isPausedProvider = StateProvider<bool>((ref) => false);

/// Error State Provider
/// Manages global error state and messages
final errorStateProvider = StateProvider<String?>((ref) => null);

/// Loading State Provider
/// Manages global loading state
final isLoadingProvider = StateProvider<bool>((ref) => false);
