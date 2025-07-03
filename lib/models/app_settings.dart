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
  
  const AppSettings({
    required this.window,
    required this.plots,
    required this.connection,
    required this.navigation,
  });
  
  factory AppSettings.defaults() {
    return AppSettings(
      window: WindowSettings.defaults(),
      plots: PlotSettings.defaults(),
      connection: ConnectionSettings.defaults(),
      navigation: NavigationSettings.defaults(),
    );
  }
  
  factory AppSettings.fromJson(Map<String, dynamic> json) => _$AppSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$AppSettingsToJson(this);
  
  AppSettings copyWith({
    WindowSettings? window,
    PlotSettings? plots,
    ConnectionSettings? connection,
    NavigationSettings? navigation,
  }) {
    return AppSettings(
      window: window ?? this.window,
      plots: plots ?? this.plots,
      connection: connection ?? this.connection,
      navigation: navigation ?? this.navigation,
    );
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
    return const WindowSettings(
      width: 1200,
      height: 800,
      maximized: false,
    );
  }
  
  factory WindowSettings.fromJson(Map<String, dynamic> json) => _$WindowSettingsFromJson(json);
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
  final int plotCount;
  final String layout; // PlotLayout enum as string
  final String timeWindow; // TimeWindowOption enum as string
  final List<PlotConfiguration> configurations;
  final String scalingMode; // ScalingMode enum as string
  final int selectedPlotIndex;
  final bool propertiesPanelVisible;
  final bool selectorPanelVisible;
  
  const PlotSettings({
    required this.plotCount,
    required this.layout,
    required this.timeWindow,
    required this.configurations,
    required this.scalingMode,
    required this.selectedPlotIndex,
    required this.propertiesPanelVisible,
    required this.selectorPanelVisible,
  });
  
  factory PlotSettings.defaults() {
    return PlotSettings(
      plotCount: 1,
      layout: 'single',
      timeWindow: '10s',
      configurations: [PlotConfiguration(id: 'plot_0')],
      scalingMode: 'autoScale',
      selectedPlotIndex: 0,
      propertiesPanelVisible: false,
      selectorPanelVisible: false,
    );
  }
  
  factory PlotSettings.fromJson(Map<String, dynamic> json) => _$PlotSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$PlotSettingsToJson(this);
  
  PlotSettings copyWith({
    int? plotCount,
    String? layout,
    String? timeWindow,
    List<PlotConfiguration>? configurations,
    String? scalingMode,
    int? selectedPlotIndex,
    bool? propertiesPanelVisible,
    bool? selectorPanelVisible,
  }) {
    return PlotSettings(
      plotCount: plotCount ?? this.plotCount,
      layout: layout ?? this.layout,
      timeWindow: timeWindow ?? this.timeWindow,
      configurations: configurations ?? this.configurations,
      scalingMode: scalingMode ?? this.scalingMode,
      selectedPlotIndex: selectedPlotIndex ?? this.selectedPlotIndex,
      propertiesPanelVisible: propertiesPanelVisible ?? this.propertiesPanelVisible,
      selectorPanelVisible: selectorPanelVisible ?? this.selectorPanelVisible,
    );
  }
}

@JsonSerializable()
class ConnectionSettings {
  final bool useSpoofMode;
  final String mavlinkHost;
  final int mavlinkPort;
  final bool autoStartMonitor;
  final bool isPaused;
  
  const ConnectionSettings({
    required this.useSpoofMode,
    required this.mavlinkHost,
    required this.mavlinkPort,
    required this.autoStartMonitor,
    required this.isPaused,
  });
  
  factory ConnectionSettings.defaults() {
    return const ConnectionSettings(
      useSpoofMode: true,
      mavlinkHost: '127.0.0.1',
      mavlinkPort: 14550,
      autoStartMonitor: true,
      isPaused: false,
    );
  }
  
  factory ConnectionSettings.fromJson(Map<String, dynamic> json) => _$ConnectionSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$ConnectionSettingsToJson(this);
  
  ConnectionSettings copyWith({
    bool? useSpoofMode,
    String? mavlinkHost,
    int? mavlinkPort,
    bool? autoStartMonitor,
    bool? isPaused,
  }) {
    return ConnectionSettings(
      useSpoofMode: useSpoofMode ?? this.useSpoofMode,
      mavlinkHost: mavlinkHost ?? this.mavlinkHost,
      mavlinkPort: mavlinkPort ?? this.mavlinkPort,
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
  
  factory NavigationSettings.fromJson(Map<String, dynamic> json) => _$NavigationSettingsFromJson(json);
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