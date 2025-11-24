import 'package:json_annotation/json_annotation.dart';
import 'package:flutter/material.dart';
import 'plot_configuration.dart';

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
  // Layout is now handled per-plot via PlotConfiguration.layoutData
  final String timeWindow; // TimeWindowOption enum as string
  final List<PlotConfiguration> configurations;
  final String scalingMode; // ScalingMode enum as string
  final int selectedPlotIndex;
  final bool propertiesPanelVisible;
  final bool selectorPanelVisible;
  final double messagePanelWidth;

  const PlotSettings({
    required this.timeWindow,
    required this.configurations,
    required this.scalingMode,
    required this.selectedPlotIndex,
    required this.propertiesPanelVisible,
    required this.selectorPanelVisible,
    required this.messagePanelWidth,
  });

  factory PlotSettings.defaults() {
    return PlotSettings(
      timeWindow: '10s',
      configurations: [PlotConfiguration(id: 'plot_0')],
      scalingMode: 'autoScale',
      selectedPlotIndex: 0,
      propertiesPanelVisible: false,
      selectorPanelVisible: false,
      messagePanelWidth: 350.0,
    );
  }

  factory PlotSettings.fromJson(Map<String, dynamic> json) =>
      _$PlotSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$PlotSettingsToJson(this);

  PlotSettings copyWith({
    String? timeWindow,
    List<PlotConfiguration>? configurations,
    String? scalingMode,
    int? selectedPlotIndex,
    bool? propertiesPanelVisible,
    bool? selectorPanelVisible,
    double? messagePanelWidth,
  }) {
    return PlotSettings(
      timeWindow: timeWindow ?? this.timeWindow,
      configurations: configurations ?? this.configurations,
      scalingMode: scalingMode ?? this.scalingMode,
      selectedPlotIndex: selectedPlotIndex ?? this.selectedPlotIndex,
      propertiesPanelVisible:
          propertiesPanelVisible ?? this.propertiesPanelVisible,
      selectorPanelVisible: selectorPanelVisible ?? this.selectorPanelVisible,
      messagePanelWidth: messagePanelWidth ?? this.messagePanelWidth,
    );
  }
}

@JsonSerializable()
class ConnectionSettings {
  // Receiving Settings
  final String connectionType; // 'udp', 'serial'
  final String mavlinkHost;
  final int mavlinkPort;
  final String serialPort;
  final int serialBaudRate;

  // Spoofing Settings
  final bool enableSpoofing;
  final String spoofMode; // 'timer', 'usb_serial'
  final int spoofBaudRate;
  final int spoofSystemId;
  final int spoofComponentId;

  // General Settings
  final bool autoStartMonitor;
  final bool isPaused;

  const ConnectionSettings({
    required this.connectionType,
    required this.mavlinkHost,
    required this.mavlinkPort,
    required this.serialPort,
    required this.serialBaudRate,
    required this.enableSpoofing,
    required this.spoofMode,
    required this.spoofBaudRate,
    required this.spoofSystemId,
    required this.spoofComponentId,
    required this.autoStartMonitor,
    required this.isPaused,
  });

  factory ConnectionSettings.defaults() {
    return const ConnectionSettings(
      // Receiving defaults
      connectionType: 'udp',
      mavlinkHost: '127.0.0.1',
      mavlinkPort: 14550,
      serialPort: '/dev/ttyUSB0',
      serialBaudRate: 57600,
      // Spoofing defaults
      enableSpoofing: true,
      spoofMode: 'usb_serial', // Only option now
      spoofBaudRate: 57600,
      spoofSystemId: 1,
      spoofComponentId: 1,
      // General defaults
      autoStartMonitor: true,
      isPaused:
          false, // Start running by default (will be overridden by persistence)
    );
  }

  factory ConnectionSettings.fromJson(Map<String, dynamic> json) =>
      _$ConnectionSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$ConnectionSettingsToJson(this);

  ConnectionSettings copyWith({
    String? connectionType,
    String? mavlinkHost,
    int? mavlinkPort,
    String? serialPort,
    int? serialBaudRate,
    bool? enableSpoofing,
    String? spoofMode,
    int? spoofBaudRate,
    int? spoofSystemId,
    int? spoofComponentId,
    bool? autoStartMonitor,
    bool? isPaused,
  }) {
    return ConnectionSettings(
      connectionType: connectionType ?? this.connectionType,
      mavlinkHost: mavlinkHost ?? this.mavlinkHost,
      mavlinkPort: mavlinkPort ?? this.mavlinkPort,
      serialPort: serialPort ?? this.serialPort,
      serialBaudRate: serialBaudRate ?? this.serialBaudRate,
      enableSpoofing: enableSpoofing ?? this.enableSpoofing,
      spoofMode: spoofMode ?? this.spoofMode,
      spoofBaudRate: spoofBaudRate ?? this.spoofBaudRate,
      spoofSystemId: spoofSystemId ?? this.spoofSystemId,
      spoofComponentId: spoofComponentId ?? this.spoofComponentId,
      autoStartMonitor: autoStartMonitor ?? this.autoStartMonitor,
      isPaused: isPaused ?? this.isPaused,
    );
  }

  // Legacy compatibility properties
  bool get useSpoofMode => enableSpoofing;
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
