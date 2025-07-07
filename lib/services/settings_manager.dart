import 'dart:async';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../models/plot_configuration.dart';
import 'settings_service.dart';

/// Central settings manager with automatic persistence and change notification
class SettingsManager extends ChangeNotifier {
  final SettingsService _settingsService = SettingsService();
  AppSettings _settings = AppSettings.defaults();
  Timer? _saveTimer;
  
  // Debounce settings saves to avoid excessive disk writes
  static const Duration _saveDelay = Duration(seconds: 2);

  AppSettings get settings => _settings;
  WindowSettings get window => _settings.window;
  PlotSettings get plots => _settings.plots;
  ConnectionSettings get connection => _settings.connection;
  NavigationSettings get navigation => _settings.navigation;
  PerformanceSettings get performance => _settings.performance;

  /// Initialize settings by loading from storage
  Future<void> initialize() async {
    try {
      _settings = await _settingsService.loadSettings();
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing settings: $e');
      // Continue with defaults
    }
  }

  /// Update window settings
  void updateWindow(WindowSettings newWindow) {
    if (_settings.window == newWindow) return;
    
    _settings = _settings.copyWith(window: newWindow);
    notifyListeners();
    
    // Save window state immediately (for window close events)
    _settingsService.saveWindowState(newWindow);
    _debouncedSave();
  }

  /// Update window size
  void updateWindowSize(Size size) {
    updateWindow(_settings.window.copyWith(
      width: size.width,
      height: size.height,
    ));
  }

  /// Update window position
  void updateWindowPosition(Offset position) {
    updateWindow(_settings.window.copyWith(
      x: position.dx,
      y: position.dy,
    ));
  }

  /// Update window maximized state
  void updateWindowMaximized(bool maximized) {
    updateWindow(_settings.window.copyWith(maximized: maximized));
  }

  /// Update window state (convenience method for all window properties)
  void updateWindowState({Size? size, Offset? position, bool? maximized}) {
    updateWindow(_settings.window.copyWith(
      width: size?.width,
      height: size?.height,
      x: position?.dx,
      y: position?.dy,
      maximized: maximized,
    ));
  }

  /// Update plot settings
  void updatePlots(PlotSettings newPlots) {
    if (_settings.plots == newPlots) return;
    
    _settings = _settings.copyWith(plots: newPlots);
    notifyListeners();
    _debouncedSave();
  }

  /// Update plot count and regenerate configurations if needed
  void updatePlotCount(int count) {
    final currentCount = _settings.plots.plotCount;
    if (currentCount == count) return;

    final configurations = <PlotConfiguration>[];
    
    // Keep existing configurations
    for (int i = 0; i < count && i < _settings.plots.configurations.length; i++) {
      configurations.add(_settings.plots.configurations[i]);
    }
    
    // Add new empty configurations if needed
    for (int i = _settings.plots.configurations.length; i < count; i++) {
      configurations.add(PlotConfiguration(id: 'plot_$i'));
    }

    updatePlots(_settings.plots.copyWith(
      plotCount: count,
      configurations: configurations,
    ));
  }

  /// Update plot layout
  void updatePlotLayout(String layout) {
    updatePlots(_settings.plots.copyWith(layout: layout));
  }

  /// Update time window
  void updateTimeWindow(String timeWindow) {
    updatePlots(_settings.plots.copyWith(timeWindow: timeWindow));
  }

  /// Update scaling mode
  void updateScalingMode(String scalingMode) {
    updatePlots(_settings.plots.copyWith(scalingMode: scalingMode));
  }

  /// Update selected plot index
  void updateSelectedPlotIndex(int index) {
    updatePlots(_settings.plots.copyWith(selectedPlotIndex: index));
  }

  /// Update panel visibility
  void updatePanelVisibility({bool? properties, bool? selector}) {
    updatePlots(_settings.plots.copyWith(
      propertiesPanelVisible: properties ?? _settings.plots.propertiesPanelVisible,
      selectorPanelVisible: selector ?? _settings.plots.selectorPanelVisible,
    ));
  }

  /// Update plot configuration at specific index
  void updatePlotConfiguration(int index, PlotConfiguration configuration) {
    if (index < 0 || index >= _settings.plots.configurations.length) return;
    
    final configurations = List<PlotConfiguration>.from(_settings.plots.configurations);
    configurations[index] = configuration;
    
    updatePlots(_settings.plots.copyWith(configurations: configurations));
  }

  /// Update connection settings
  void updateConnection(ConnectionSettings newConnection) {
    if (_settings.connection == newConnection) return;
    
    _settings = _settings.copyWith(connection: newConnection);
    notifyListeners();
    _debouncedSave();
  }

  /// Update connection mode (spoof vs real)
  void updateConnectionMode(bool enableSpoofing, {String? spoofMode}) {
    updateConnection(_settings.connection.copyWith(
      enableSpoofing: enableSpoofing,
      spoofMode: spoofMode ?? _settings.connection.spoofMode,
    ));
  }
  
  /// Update receiving connection type
  void updateConnectionType(String connectionType) {
    updateConnection(_settings.connection.copyWith(connectionType: connectionType));
  }
  
  /// Update serial connection settings
  void updateSerialConnection(String port, int baudRate) {
    updateConnection(_settings.connection.copyWith(
      serialPort: port,
      serialBaudRate: baudRate,
    ));
  }
  
  /// Update spoofing configuration
  void updateSpoofingConfig({
    String? spoofMode,
    int? spoofBaudRate,
    int? spoofSystemId,
    int? spoofComponentId,
  }) {
    updateConnection(_settings.connection.copyWith(
      spoofMode: spoofMode,
      spoofBaudRate: spoofBaudRate,
      spoofSystemId: spoofSystemId,
      spoofComponentId: spoofComponentId,
    ));
  }

  /// Update MAVLink connection details
  void updateMavlinkConnection(String host, int port) {
    updateConnection(_settings.connection.copyWith(
      mavlinkHost: host,
      mavlinkPort: port,
    ));
  }

  /// Update auto-start monitor setting
  void updateAutoStartMonitor(bool autoStart) {
    updateConnection(_settings.connection.copyWith(autoStartMonitor: autoStart));
  }

  /// Update pause state
  void updatePauseState(bool isPaused) {
    updateConnection(_settings.connection.copyWith(isPaused: isPaused));
  }

  /// Update navigation settings
  void updateNavigation(NavigationSettings newNavigation) {
    if (_settings.navigation == newNavigation) return;
    
    _settings = _settings.copyWith(navigation: newNavigation);
    notifyListeners();
    _debouncedSave();
  }

  /// Update selected view index
  void updateSelectedViewIndex(int index) {
    updateNavigation(_settings.navigation.copyWith(selectedViewIndex: index));
  }

  /// Update selected plot index in navigation
  void updateSelectedPlotInNavigation(int index) {
    updateNavigation(_settings.navigation.copyWith(selectedPlotIndex: index));
  }

  /// Update performance settings
  void updatePerformance(PerformanceSettings newPerformance) {
    if (_settings.performance == newPerformance) return;
    
    _settings = _settings.copyWith(performance: newPerformance);
    notifyListeners();
    _debouncedSave();
  }

  /// Update point decimation settings
  void updatePointDecimation({bool? enabled, int? threshold}) {
    updatePerformance(_settings.performance.copyWith(
      enablePointDecimation: enabled,
      decimationThreshold: threshold,
    ));
  }

  /// Update throttling settings
  void updateThrottling({bool? enabled, int? interval}) {
    updatePerformance(_settings.performance.copyWith(
      enableUpdateThrottling: enabled,
      updateInterval: interval,
    ));
  }

  /// Update animation settings
  void updateAnimations({bool? enabled, int? duration}) {
    updatePerformance(_settings.performance.copyWith(
      enableSmoothAnimations: enabled,
      animationDuration: duration,
    ));
  }

  /// Update data management settings
  void updateDataManagement({int? bufferSize, int? retentionMinutes}) {
    updatePerformance(_settings.performance.copyWith(
      dataBufferSize: bufferSize,
      dataRetentionMinutes: retentionMinutes,
    ));
  }

  /// Force immediate save (for app shutdown)
  Future<void> saveImmediately() async {
    _saveTimer?.cancel();
    await _settingsService.saveSettings(_settings);
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await _settingsService.clearAllSettings();
    _settings = AppSettings.defaults();
    notifyListeners();
  }

  /// Export settings as JSON string
  Future<String?> exportSettings() async {
    return await _settingsService.exportSettings();
  }

  /// Import settings from JSON string
  Future<bool> importSettings(String settingsJson) async {
    final success = await _settingsService.importSettings(settingsJson);
    if (success) {
      await initialize(); // Reload settings
    }
    return success;
  }

  /// Debounced save to avoid excessive disk writes
  void _debouncedSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, () async {
      await _settingsService.saveSettings(_settings);
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}