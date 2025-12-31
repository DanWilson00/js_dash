import 'dart:async';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/app_settings.dart';
import '../models/plot_configuration.dart';
import '../models/plot_tab.dart';
import 'settings_service.dart';

part 'settings_manager.g.dart';

/// Central settings manager with automatic persistence and change notification
/// Uses Riverpod's AsyncNotifier for reactive state management
@Riverpod(keepAlive: true)
class Settings extends _$Settings {
  final SettingsService _settingsService = SettingsService();
  Timer? _saveTimer;
  static const Duration _saveDelay = Duration(seconds: 2);

  /// Optional initial settings to avoid async loading race condition
  static AppSettings? _initialSettings;

  /// Call before app starts to provide pre-loaded settings
  static void setInitialSettings(AppSettings settings) {
    _initialSettings = settings;
  }

  /// Get initial settings synchronously (for initState use)
  /// This bypasses the async provider loading state
  static AppSettings getInitialSettings() {
    return _initialSettings ?? AppSettings.defaults();
  }

  @override
  Future<AppSettings> build() async {
    ref.onDispose(() {
      _saveTimer?.cancel();
    });

    // Use pre-loaded settings if available (avoids race condition on startup)
    if (_initialSettings != null) {
      return _initialSettings!;
    }

    // Fall back to loading from disk
    try {
      return await _settingsService.loadSettings();
    } catch (e) {
      debugPrint('Error initializing settings: $e');
      return AppSettings.defaults();
    }
  }

  // Helper to get current settings or defaults
  AppSettings get _current => state.value ?? AppSettings.defaults();

  // Helper to update state and schedule save
  void _update(AppSettings newSettings) {
    state = AsyncData(newSettings);
    _debouncedSave();
  }

  // Convenience getters for sub-settings
  WindowSettings get window => _current.window;
  PlotSettings get plots => _current.plots;
  ConnectionSettings get connection => _current.connection;
  NavigationSettings get navigation => _current.navigation;
  PerformanceSettings get performance => _current.performance;
  MapSettings get map => _current.map;
  AppearanceSettings get appearance => _current.appearance;

  /// Update appearance settings
  void updateAppearance(AppearanceSettings newAppearance) {
    if (_current.appearance == newAppearance) return;
    _update(_current.copyWith(appearance: newAppearance));
  }

  /// Update UI scale
  void updateUiScale(double scale) {
    updateAppearance(_current.appearance.copyWith(uiScale: scale));
  }

  /// Update window settings
  void updateWindow(WindowSettings newWindow) {
    if (_current.window == newWindow) return;
    _update(_current.copyWith(window: newWindow));
  }

  /// Update window size
  void updateWindowSize(Size size) {
    updateWindow(_current.window.copyWith(width: size.width, height: size.height));
  }

  /// Update window position
  void updateWindowPosition(Offset position) {
    updateWindow(_current.window.copyWith(x: position.dx, y: position.dy));
  }

  /// Update window maximized state
  void updateWindowMaximized(bool maximized) {
    updateWindow(_current.window.copyWith(maximized: maximized));
  }

  /// Update window state (convenience method for all window properties)
  void updateWindowState({Size? size, Offset? position, bool? maximized}) {
    updateWindow(_current.window.copyWith(
      width: size?.width,
      height: size?.height,
      x: position?.dx,
      y: position?.dy,
      maximized: maximized,
    ));
  }

  /// Update plot settings
  void updatePlots(PlotSettings newPlots) {
    if (_current.plots == newPlots) return;
    _update(_current.copyWith(plots: newPlots));
  }

  // Plot Settings
  void updateTimeWindow(String timeWindow) {
    _update(_current.copyWith(
      plots: _current.plots.copyWith(timeWindow: timeWindow),
    ));
  }

  void updateMessagePanelWidth(double width) {
    _update(_current.copyWith(
      plots: _current.plots.copyWith(messagePanelWidth: width),
    ));
  }

  // Tab Management
  void addPlotTab(String name) {
    final newTab = PlotTab(
      id: 'tab_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      plots: [],
    );
    final updatedTabs = List<PlotTab>.from(_current.plots.tabs)..add(newTab);

    _update(_current.copyWith(
      plots: _current.plots.copyWith(
        tabs: updatedTabs,
        selectedTabId: newTab.id,
      ),
    ));
  }

  void removePlotTab(String tabId) {
    if (_current.plots.tabs.length <= 1) return; // Prevent removing last tab

    final updatedTabs = List<PlotTab>.from(_current.plots.tabs)
      ..removeWhere((t) => t.id == tabId);

    // If we removed the selected tab, select the last one
    String newSelectedId = _current.plots.selectedTabId;
    if (tabId == _current.plots.selectedTabId) {
      newSelectedId = updatedTabs.last.id;
    }

    _update(_current.copyWith(
      plots: _current.plots.copyWith(
        tabs: updatedTabs,
        selectedTabId: newSelectedId,
      ),
    ));
  }

  void renamePlotTab(String tabId, String newName) {
    final updatedTabs = _current.plots.tabs.map((tab) {
      return tab.id == tabId ? tab.copyWith(name: newName) : tab;
    }).toList();

    _update(_current.copyWith(
      plots: _current.plots.copyWith(tabs: updatedTabs),
    ));
  }

  void selectPlotTab(String tabId) {
    if (_current.plots.selectedTabId == tabId) return;

    _update(_current.copyWith(
      plots: _current.plots.copyWith(selectedTabId: tabId),
    ));
  }

  void updatePlotsInTab(String tabId, List<PlotConfiguration> plots) {
    final updatedTabs = _current.plots.tabs.map((tab) {
      return tab.id == tabId ? tab.copyWith(plots: plots) : tab;
    }).toList();

    _update(_current.copyWith(
      plots: _current.plots.copyWith(tabs: updatedTabs),
    ));
  }

  PlotTab? getCurrentTab() {
    try {
      return _current.plots.tabs.firstWhere(
        (t) => t.id == _current.plots.selectedTabId,
      );
    } catch (_) {
      return _current.plots.tabs.isNotEmpty ? _current.plots.tabs.first : null;
    }
  }

  /// Update connection settings
  void updateConnection(ConnectionSettings newConnection) {
    if (_current.connection == newConnection) return;
    _update(_current.copyWith(connection: newConnection));
  }

  /// Update connection mode (spoof vs real)
  void updateConnectionMode(bool enableSpoofing) {
    updateConnection(_current.connection.copyWith(enableSpoofing: enableSpoofing));
  }

  /// Update serial connection settings
  void updateSerialConnection(String port, int baudRate) {
    updateConnection(_current.connection.copyWith(
      serialPort: port,
      serialBaudRate: baudRate,
    ));
  }

  /// Update spoofing configuration
  void updateSpoofingConfig({
    int? spoofBaudRate,
    int? spoofSystemId,
    int? spoofComponentId,
  }) {
    updateConnection(_current.connection.copyWith(
      spoofBaudRate: spoofBaudRate,
      spoofSystemId: spoofSystemId,
      spoofComponentId: spoofComponentId,
    ));
  }

  /// Update auto-start monitor setting
  void updateAutoStartMonitor(bool autoStart) {
    updateConnection(_current.connection.copyWith(autoStartMonitor: autoStart));
  }

  /// Update MAVLink dialect setting
  void updateMavlinkDialect(String dialect) {
    if (_current.connection.mavlinkDialect == dialect) return;
    updateConnection(_current.connection.copyWith(mavlinkDialect: dialect));
  }

  /// Update pause state
  void updatePauseState(bool isPaused) {
    updateConnection(_current.connection.copyWith(isPaused: isPaused));
  }

  /// Update navigation settings
  void updateNavigation(NavigationSettings newNavigation) {
    if (_current.navigation == newNavigation) return;
    _update(_current.copyWith(navigation: newNavigation));
  }

  /// Update selected view index
  void updateSelectedViewIndex(int index) {
    updateNavigation(_current.navigation.copyWith(selectedViewIndex: index));
  }

  /// Update selected plot index in navigation
  void updateSelectedPlotInNavigation(int index) {
    updateNavigation(_current.navigation.copyWith(selectedPlotIndex: index));
  }

  /// Update performance settings
  void updatePerformance(PerformanceSettings newPerformance) {
    if (_current.performance == newPerformance) return;
    _update(_current.copyWith(performance: newPerformance));
  }

  /// Update point decimation settings
  void updatePointDecimation({bool? enabled, int? threshold}) {
    updatePerformance(_current.performance.copyWith(
      enablePointDecimation: enabled,
      decimationThreshold: threshold,
    ));
  }

  /// Update throttling settings
  void updateThrottling({bool? enabled, int? interval}) {
    updatePerformance(_current.performance.copyWith(
      enableUpdateThrottling: enabled,
      updateInterval: interval,
    ));
  }

  /// Update data management settings
  void updateDataManagement({int? bufferSize, int? retentionMinutes}) {
    updatePerformance(_current.performance.copyWith(
      dataBufferSize: bufferSize,
      dataRetentionMinutes: retentionMinutes,
    ));
  }

  /// Update map settings
  void updateMap(MapSettings newMap) {
    if (_current.map == newMap) return;
    _update(_current.copyWith(map: newMap));
  }

  /// Update map center position
  void updateMapCenter(double latitude, double longitude) {
    updateMap(_current.map.copyWith(
      centerLatitude: latitude,
      centerLongitude: longitude,
    ));
  }

  /// Update map zoom level
  void updateMapZoom(double zoomLevel) {
    updateMap(_current.map.copyWith(zoomLevel: zoomLevel));
  }

  /// Update map center and zoom together (common operation)
  void updateMapCenterAndZoom(double latitude, double longitude, double zoomLevel) {
    updateMap(_current.map.copyWith(
      centerLatitude: latitude,
      centerLongitude: longitude,
      zoomLevel: zoomLevel,
    ));
  }

  /// Update vehicle following setting
  void updateMapFollowVehicle(bool followVehicle) {
    updateMap(_current.map.copyWith(followVehicle: followVehicle));
  }

  /// Update map path visibility
  void updateMapShowPath(bool showPath) {
    updateMap(_current.map.copyWith(showPath: showPath));
  }

  /// Update map max path points
  void updateMapMaxPathPoints(int maxPoints) {
    updateMap(_current.map.copyWith(maxPathPoints: maxPoints));
  }

  Future<void> resetToDefaults() async {
    await _settingsService.clearAllSettings();
    state = AsyncData(AppSettings.defaults());
  }

  /// Export settings as JSON string
  Future<String?> exportSettings() async {
    return await _settingsService.exportSettings();
  }

  /// Import settings from JSON string
  Future<bool> importSettings(String settingsJson) async {
    final success = await _settingsService.importSettings(settingsJson);
    if (success) {
      // Reload settings
      state = const AsyncLoading();
      state = AsyncData(await _settingsService.loadSettings());
    }
    return success;
  }

  /// Force immediate save
  Future<void> saveNow() async {
    _saveTimer?.cancel();
    await _settingsService.saveSettings(_current);
  }

  /// Debounced save to avoid excessive disk writes
  void _debouncedSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, () async {
      await _settingsService.saveSettings(_current);
    });
  }
}
