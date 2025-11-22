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
  performance: PerformanceSettings.fromJson(
    json['performance'] as Map<String, dynamic>,
  ),
  map: MapSettings.fromJson(json['map'] as Map<String, dynamic>),
  appearance: AppearanceSettings.fromJson(
    json['appearance'] as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$AppSettingsToJson(AppSettings instance) =>
    <String, dynamic>{
      'window': instance.window,
      'plots': instance.plots,
      'connection': instance.connection,
      'navigation': instance.navigation,
      'performance': instance.performance,
      'map': instance.map,
      'appearance': instance.appearance,
    };

AppearanceSettings _$AppearanceSettingsFromJson(Map<String, dynamic> json) =>
    AppearanceSettings(uiScale: (json['uiScale'] as num).toDouble());

Map<String, dynamic> _$AppearanceSettingsToJson(AppearanceSettings instance) =>
    <String, dynamic>{'uiScale': instance.uiScale};

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
      'timeWindow': instance.timeWindow,
      'configurations': instance.configurations,
      'scalingMode': instance.scalingMode,
      'selectedPlotIndex': instance.selectedPlotIndex,
      'propertiesPanelVisible': instance.propertiesPanelVisible,
      'selectorPanelVisible': instance.selectorPanelVisible,
    };

ConnectionSettings _$ConnectionSettingsFromJson(Map<String, dynamic> json) =>
    ConnectionSettings(
      connectionType: json['connectionType'] as String,
      mavlinkHost: json['mavlinkHost'] as String,
      mavlinkPort: (json['mavlinkPort'] as num).toInt(),
      serialPort: json['serialPort'] as String,
      serialBaudRate: (json['serialBaudRate'] as num).toInt(),
      enableSpoofing: json['enableSpoofing'] as bool,
      spoofMode: json['spoofMode'] as String,
      spoofBaudRate: (json['spoofBaudRate'] as num).toInt(),
      spoofSystemId: (json['spoofSystemId'] as num).toInt(),
      spoofComponentId: (json['spoofComponentId'] as num).toInt(),
      autoStartMonitor: json['autoStartMonitor'] as bool,
      isPaused: json['isPaused'] as bool,
    );

Map<String, dynamic> _$ConnectionSettingsToJson(ConnectionSettings instance) =>
    <String, dynamic>{
      'connectionType': instance.connectionType,
      'mavlinkHost': instance.mavlinkHost,
      'mavlinkPort': instance.mavlinkPort,
      'serialPort': instance.serialPort,
      'serialBaudRate': instance.serialBaudRate,
      'enableSpoofing': instance.enableSpoofing,
      'spoofMode': instance.spoofMode,
      'spoofBaudRate': instance.spoofBaudRate,
      'spoofSystemId': instance.spoofSystemId,
      'spoofComponentId': instance.spoofComponentId,
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

PerformanceSettings _$PerformanceSettingsFromJson(Map<String, dynamic> json) =>
    PerformanceSettings(
      enablePointDecimation: json['enablePointDecimation'] as bool,
      decimationThreshold: (json['decimationThreshold'] as num).toInt(),
      enableUpdateThrottling: json['enableUpdateThrottling'] as bool,
      updateInterval: (json['updateInterval'] as num).toInt(),
      enableSmoothAnimations: json['enableSmoothAnimations'] as bool,
      animationDuration: (json['animationDuration'] as num).toInt(),
      dataBufferSize: (json['dataBufferSize'] as num).toInt(),
      dataRetentionMinutes: (json['dataRetentionMinutes'] as num).toInt(),
    );

Map<String, dynamic> _$PerformanceSettingsToJson(
  PerformanceSettings instance,
) => <String, dynamic>{
  'enablePointDecimation': instance.enablePointDecimation,
  'decimationThreshold': instance.decimationThreshold,
  'enableUpdateThrottling': instance.enableUpdateThrottling,
  'updateInterval': instance.updateInterval,
  'enableSmoothAnimations': instance.enableSmoothAnimations,
  'animationDuration': instance.animationDuration,
  'dataBufferSize': instance.dataBufferSize,
  'dataRetentionMinutes': instance.dataRetentionMinutes,
};

MapSettings _$MapSettingsFromJson(Map<String, dynamic> json) => MapSettings(
  centerLatitude: (json['centerLatitude'] as num).toDouble(),
  centerLongitude: (json['centerLongitude'] as num).toDouble(),
  zoomLevel: (json['zoomLevel'] as num).toDouble(),
  followVehicle: json['followVehicle'] as bool,
  showPath: json['showPath'] as bool,
  maxPathPoints: (json['maxPathPoints'] as num).toInt(),
);

Map<String, dynamic> _$MapSettingsToJson(MapSettings instance) =>
    <String, dynamic>{
      'centerLatitude': instance.centerLatitude,
      'centerLongitude': instance.centerLongitude,
      'zoomLevel': instance.zoomLevel,
      'followVehicle': instance.followVehicle,
      'showPath': instance.showPath,
      'maxPathPoints': instance.maxPathPoints,
    };
