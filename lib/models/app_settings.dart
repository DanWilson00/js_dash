import 'package:json_annotation/json_annotation.dart';
import 'package:flutter/material.dart';
import 'plot_configuration.dart';
import 'plot_tab.dart';

part 'app_settings.g.dart';

@JsonSerializable()
class AppSettings {
  final WindowSettings window;
  final PlotSettings plots;
  final ConnectionSettings connection;
  final NavigationSettings navigation;
  final PerformanceSettings performance;
  final MapSettings map;
  final AppearanceSettings appearance;

  const AppSettings({
    required this.window,
    required this.plots,
    required this.connection,
    required this.navigation,
    required this.performance,
    required this.map,
    required this.appearance,
  });

  factory AppSettings.defaults() {
    return AppSettings(
      window: WindowSettings.defaults(),
      plots: PlotSettings.defaults(),
      connection: ConnectionSettings.defaults(),
      navigation: NavigationSettings.defaults(),
      performance: PerformanceSettings.defaults(),
      map: MapSettings.defaults(),
      appearance: AppearanceSettings.defaults(),
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$AppSettingsToJson(this);

  AppSettings copyWith({
    WindowSettings? window,
    PlotSettings? plots,
    ConnectionSettings? connection,
    NavigationSettings? navigation,
    PerformanceSettings? performance,
    MapSettings? map,
    AppearanceSettings? appearance,
  }) {
    return AppSettings(
      window: window ?? this.window,
      plots: plots ?? this.plots,
      connection: connection ?? this.connection,
      navigation: navigation ?? this.navigation,
      performance: performance ?? this.performance,
      map: map ?? this.map,
      appearance: appearance ?? this.appearance,
    );
  }
}

@JsonSerializable()
class AppearanceSettings {
  final double uiScale;

  const AppearanceSettings({required this.uiScale});

  factory AppearanceSettings.defaults() {
    return const AppearanceSettings(uiScale: 1.0);
  }

  factory AppearanceSettings.fromJson(Map<String, dynamic> json) =>
      _$AppearanceSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$AppearanceSettingsToJson(this);

  AppearanceSettings copyWith({double? uiScale}) {
    return AppearanceSettings(uiScale: uiScale ?? this.uiScale);
  }
}

@JsonSerializable()
class WindowSettings {
  final double width;
  final double height;
  final double? x;
  final double? y;
  final bool maximized;

  const WindowSettings({
    required this.width,
    required this.height,
    this.x,
    this.y,
    this.maximized = false,
  });

  factory WindowSettings.defaults() {
    return const WindowSettings(width: 1200, height: 800, maximized: false);
  }

  factory WindowSettings.fromJson(Map<String, dynamic> json) =>
      _$WindowSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$WindowSettingsToJson(this);

  Size get size => Size(width, height);
  Offset? get position => x != null && y != null ? Offset(x!, y!) : null;

  WindowSettings copyWith({
    double? width,
    double? height,
    double? x,
    double? y,
    bool? maximized,
  }) {
    return WindowSettings(
      width: width ?? this.width,
      height: height ?? this.height,
      x: x ?? this.x,
      y: y ?? this.y,
      maximized: maximized ?? this.maximized,
    );
  }
}

@JsonSerializable()
class PlotSettings {
  final List<PlotTab> tabs;
  final String selectedTabId;
  final String timeWindow;
  final double messagePanelWidth;
  final bool propertiesPanelVisible;

  const PlotSettings({
    this.tabs = const [],
    this.selectedTabId = 'main',
    this.timeWindow = '1 Minute',
    this.messagePanelWidth = 350.0,
    this.propertiesPanelVisible = false,
  });

  factory PlotSettings.defaults() {
    return const PlotSettings(
      tabs: [PlotTab(id: 'main', name: 'Main', plots: [])],
      selectedTabId: 'main',
      timeWindow: '1 Minute',
      messagePanelWidth: 350.0,
      propertiesPanelVisible: false,
    );
  }

  PlotSettings copyWith({
    List<PlotTab>? tabs,
    String? selectedTabId,
    String? timeWindow,
    double? messagePanelWidth,
    bool? propertiesPanelVisible,
  }) {
    return PlotSettings(
      tabs: tabs ?? this.tabs,
      selectedTabId: selectedTabId ?? this.selectedTabId,
      timeWindow: timeWindow ?? this.timeWindow,
      messagePanelWidth: messagePanelWidth ?? this.messagePanelWidth,
      propertiesPanelVisible:
          propertiesPanelVisible ?? this.propertiesPanelVisible,
    );
  }

  factory PlotSettings.fromJson(Map<String, dynamic> json) {
    // Migration logic for old format
    if (json['configurations'] != null && json['tabs'] == null) {
      final oldPlots = (json['configurations'] as List)
          .map((e) => PlotConfiguration.fromJson(e as Map<String, dynamic>))
          .toList();

      return PlotSettings(
        tabs: [PlotTab(id: 'main', name: 'Main', plots: oldPlots)],
        selectedTabId: 'main',
        timeWindow: json['timeWindow'] as String? ?? '1 Minute',
        messagePanelWidth:
            (json['messagePanelWidth'] as num?)?.toDouble() ?? 350.0,
      );
    }

    return _$PlotSettingsFromJson(json);
  }

  Map<String, dynamic> toJson() => _$PlotSettingsToJson(this);
}

@JsonSerializable()
class ConnectionSettings {
  // Serial Connection Settings
  final String serialPort;
  final int serialBaudRate;

  // Spoofing Settings
  final bool enableSpoofing;
  final int spoofBaudRate;
  final int spoofSystemId;
  final int spoofComponentId;

  // General Settings
  final bool autoStartMonitor;
  final bool isPaused;

  const ConnectionSettings({
    required this.serialPort,
    required this.serialBaudRate,
    required this.enableSpoofing,
    required this.spoofBaudRate,
    required this.spoofSystemId,
    required this.spoofComponentId,
    required this.autoStartMonitor,
    required this.isPaused,
  });

  factory ConnectionSettings.defaults() {
    return const ConnectionSettings(
      // Serial defaults
      serialPort: '/dev/ttyUSB0',
      serialBaudRate: 57600,
      // Spoofing defaults
      enableSpoofing: true,
      spoofBaudRate: 57600,
      spoofSystemId: 1,
      spoofComponentId: 1,
      // General defaults
      autoStartMonitor: true,
      isPaused: false,
    );
  }

  factory ConnectionSettings.fromJson(Map<String, dynamic> json) {
    // Try to use generated function, but handle missing fields for migration
    try {
      return _$ConnectionSettingsFromJson(json);
    } catch (_) {
      // Migration: handle old settings with missing fields
      return ConnectionSettings(
        serialPort: json['serialPort'] as String? ?? '/dev/ttyUSB0',
        serialBaudRate: (json['serialBaudRate'] as num?)?.toInt() ?? 57600,
        enableSpoofing: json['enableSpoofing'] as bool? ?? true,
        spoofBaudRate: (json['spoofBaudRate'] as num?)?.toInt() ?? 57600,
        spoofSystemId: (json['spoofSystemId'] as num?)?.toInt() ?? 1,
        spoofComponentId: (json['spoofComponentId'] as num?)?.toInt() ?? 1,
        autoStartMonitor: json['autoStartMonitor'] as bool? ?? true,
        isPaused: json['isPaused'] as bool? ?? false,
      );
    }
  }

  Map<String, dynamic> toJson() => _$ConnectionSettingsToJson(this);

  ConnectionSettings copyWith({
    String? serialPort,
    int? serialBaudRate,
    bool? enableSpoofing,
    int? spoofBaudRate,
    int? spoofSystemId,
    int? spoofComponentId,
    bool? autoStartMonitor,
    bool? isPaused,
  }) {
    return ConnectionSettings(
      serialPort: serialPort ?? this.serialPort,
      serialBaudRate: serialBaudRate ?? this.serialBaudRate,
      enableSpoofing: enableSpoofing ?? this.enableSpoofing,
      spoofBaudRate: spoofBaudRate ?? this.spoofBaudRate,
      spoofSystemId: spoofSystemId ?? this.spoofSystemId,
      spoofComponentId: spoofComponentId ?? this.spoofComponentId,
      autoStartMonitor: autoStartMonitor ?? this.autoStartMonitor,
      isPaused: isPaused ?? this.isPaused,
    );
  }
}

@JsonSerializable()
class NavigationSettings {
  final int selectedViewIndex;
  final int selectedPlotIndex;

  const NavigationSettings({
    required this.selectedViewIndex,
    required this.selectedPlotIndex,
  });

  factory NavigationSettings.defaults() {
    return const NavigationSettings(
      selectedViewIndex: 0, // Start on telemetry view
      selectedPlotIndex: 0, // First plot selected
    );
  }

  factory NavigationSettings.fromJson(Map<String, dynamic> json) =>
      _$NavigationSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$NavigationSettingsToJson(this);

  NavigationSettings copyWith({
    int? selectedViewIndex,
    int? selectedPlotIndex,
  }) {
    return NavigationSettings(
      selectedViewIndex: selectedViewIndex ?? this.selectedViewIndex,
      selectedPlotIndex: selectedPlotIndex ?? this.selectedPlotIndex,
    );
  }
}

@JsonSerializable()
class PerformanceSettings {
  final bool enablePointDecimation;
  final int decimationThreshold;
  final bool enableUpdateThrottling;
  final int updateInterval; // milliseconds
  final int dataBufferSize;
  final int dataRetentionMinutes;

  const PerformanceSettings({
    required this.enablePointDecimation,
    required this.decimationThreshold,
    required this.enableUpdateThrottling,
    required this.updateInterval,
    required this.dataBufferSize,
    required this.dataRetentionMinutes,
  });

  factory PerformanceSettings.defaults() {
    return const PerformanceSettings(
      enablePointDecimation: true,
      decimationThreshold: 1000,
      enableUpdateThrottling: true,
      updateInterval: 100, // 10 FPS
      dataBufferSize: 2000,
      dataRetentionMinutes: 10,
    );
  }

  factory PerformanceSettings.fromJson(Map<String, dynamic> json) =>
      _$PerformanceSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$PerformanceSettingsToJson(this);

  PerformanceSettings copyWith({
    bool? enablePointDecimation,
    int? decimationThreshold,
    bool? enableUpdateThrottling,
    int? updateInterval,
    int? dataBufferSize,
    int? dataRetentionMinutes,
  }) {
    return PerformanceSettings(
      enablePointDecimation:
          enablePointDecimation ?? this.enablePointDecimation,
      decimationThreshold: decimationThreshold ?? this.decimationThreshold,
      enableUpdateThrottling:
          enableUpdateThrottling ?? this.enableUpdateThrottling,
      updateInterval: updateInterval ?? this.updateInterval,
      dataBufferSize: dataBufferSize ?? this.dataBufferSize,
      dataRetentionMinutes: dataRetentionMinutes ?? this.dataRetentionMinutes,
    );
  }
}

@JsonSerializable()
class MapSettings {
  final double centerLatitude;
  final double centerLongitude;
  final double zoomLevel;
  final bool followVehicle;
  final bool showPath;
  final int maxPathPoints;

  const MapSettings({
    required this.centerLatitude,
    required this.centerLongitude,
    required this.zoomLevel,
    required this.followVehicle,
    required this.showPath,
    required this.maxPathPoints,
  });

  factory MapSettings.defaults() {
    return const MapSettings(
      centerLatitude:
          34.0522, // Los Angeles area - matches spoofer starting point
      centerLongitude: -118.2437,
      zoomLevel: 15.0,
      followVehicle:
          false, // Default to static map that remembers position/zoom
      showPath: true,
      maxPathPoints: 200,
    );
  }

  factory MapSettings.fromJson(Map<String, dynamic> json) =>
      _$MapSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$MapSettingsToJson(this);

  MapSettings copyWith({
    double? centerLatitude,
    double? centerLongitude,
    double? zoomLevel,
    bool? followVehicle,
    bool? showPath,
    int? maxPathPoints,
  }) {
    return MapSettings(
      centerLatitude: centerLatitude ?? this.centerLatitude,
      centerLongitude: centerLongitude ?? this.centerLongitude,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      followVehicle: followVehicle ?? this.followVehicle,
      showPath: showPath ?? this.showPath,
      maxPathPoints: maxPathPoints ?? this.maxPathPoints,
    );
  }
}
