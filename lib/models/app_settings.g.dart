// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) => AppSettings(
  window: WindowSettings.fromJson(json['window'] as Map<String, dynamic>),
  plots: PlotSettings.fromJson(json['plots'] as Map<String, dynamic>),
  connection: ConnectionSettings.fromJson(
    json['connection'] as Map<String, dynamic>,
  ),
  navigation: NavigationSettings.fromJson(
    json['navigation'] as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$AppSettingsToJson(AppSettings instance) =>
    <String, dynamic>{
      'window': instance.window,
      'plots': instance.plots,
      'connection': instance.connection,
      'navigation': instance.navigation,
    };

WindowSettings _$WindowSettingsFromJson(Map<String, dynamic> json) =>
    WindowSettings(
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      x: (json['x'] as num?)?.toDouble(),
      y: (json['y'] as num?)?.toDouble(),
      maximized: json['maximized'] as bool? ?? false,
    );

Map<String, dynamic> _$WindowSettingsToJson(WindowSettings instance) =>
    <String, dynamic>{
      'width': instance.width,
      'height': instance.height,
      'x': instance.x,
      'y': instance.y,
      'maximized': instance.maximized,
    };

PlotSettings _$PlotSettingsFromJson(Map<String, dynamic> json) => PlotSettings(
  plotCount: (json['plotCount'] as num).toInt(),
  layout: json['layout'] as String,
  timeWindow: json['timeWindow'] as String,
  configurations: (json['configurations'] as List<dynamic>)
      .map((e) => PlotConfiguration.fromJson(e as Map<String, dynamic>))
      .toList(),
  scalingMode: json['scalingMode'] as String,
  selectedPlotIndex: (json['selectedPlotIndex'] as num).toInt(),
  propertiesPanelVisible: json['propertiesPanelVisible'] as bool,
  selectorPanelVisible: json['selectorPanelVisible'] as bool,
);

Map<String, dynamic> _$PlotSettingsToJson(PlotSettings instance) =>
    <String, dynamic>{
      'plotCount': instance.plotCount,
      'layout': instance.layout,
      'timeWindow': instance.timeWindow,
      'configurations': instance.configurations,
      'scalingMode': instance.scalingMode,
      'selectedPlotIndex': instance.selectedPlotIndex,
      'propertiesPanelVisible': instance.propertiesPanelVisible,
      'selectorPanelVisible': instance.selectorPanelVisible,
    };

ConnectionSettings _$ConnectionSettingsFromJson(Map<String, dynamic> json) =>
    ConnectionSettings(
      useSpoofMode: json['useSpoofMode'] as bool,
      mavlinkHost: json['mavlinkHost'] as String,
      mavlinkPort: (json['mavlinkPort'] as num).toInt(),
      autoStartMonitor: json['autoStartMonitor'] as bool,
      isPaused: json['isPaused'] as bool,
    );

Map<String, dynamic> _$ConnectionSettingsToJson(ConnectionSettings instance) =>
    <String, dynamic>{
      'useSpoofMode': instance.useSpoofMode,
      'mavlinkHost': instance.mavlinkHost,
      'mavlinkPort': instance.mavlinkPort,
      'autoStartMonitor': instance.autoStartMonitor,
      'isPaused': instance.isPaused,
    };

NavigationSettings _$NavigationSettingsFromJson(Map<String, dynamic> json) =>
    NavigationSettings(
      selectedViewIndex: (json['selectedViewIndex'] as num).toInt(),
      selectedPlotIndex: (json['selectedPlotIndex'] as num).toInt(),
    );

Map<String, dynamic> _$NavigationSettingsToJson(NavigationSettings instance) =>
    <String, dynamic>{
      'selectedViewIndex': instance.selectedViewIndex,
      'selectedPlotIndex': instance.selectedPlotIndex,
    };
