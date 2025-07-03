// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plot_configuration.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlotSignalConfiguration _$PlotSignalConfigurationFromJson(
  Map<String, dynamic> json,
) => PlotSignalConfiguration(
  id: json['id'] as String,
  messageType: json['messageType'] as String,
  fieldName: json['fieldName'] as String,
  units: json['units'] as String?,
  color: const ColorConverter().fromJson((json['color'] as num).toInt()),
  visible: json['visible'] as bool? ?? true,
  displayName: json['displayName'] as String?,
  lineWidth: (json['lineWidth'] as num?)?.toDouble() ?? 2.0,
  showDots: json['showDots'] as bool? ?? false,
);

Map<String, dynamic> _$PlotSignalConfigurationToJson(
  PlotSignalConfiguration instance,
) => <String, dynamic>{
  'id': instance.id,
  'messageType': instance.messageType,
  'fieldName': instance.fieldName,
  'units': instance.units,
  'color': const ColorConverter().toJson(instance.color),
  'visible': instance.visible,
  'displayName': instance.displayName,
  'lineWidth': instance.lineWidth,
  'showDots': instance.showDots,
};

PlotAxisConfiguration _$PlotAxisConfigurationFromJson(
  Map<String, dynamic> json,
) => PlotAxisConfiguration(
  signals: (json['signals'] as List<dynamic>?)
      ?.map((e) => PlotSignalConfiguration.fromJson(e as Map<String, dynamic>))
      .toList(),
  minY: (json['minY'] as num?)?.toDouble(),
  maxY: (json['maxY'] as num?)?.toDouble(),
  scalingMode:
      $enumDecodeNullable(_$ScalingModeEnumMap, json['scalingMode']) ??
      ScalingMode.autoScale,
);

Map<String, dynamic> _$PlotAxisConfigurationToJson(
  PlotAxisConfiguration instance,
) => <String, dynamic>{
  'signals': instance.signals,
  'minY': instance.minY,
  'maxY': instance.maxY,
  'scalingMode': _$ScalingModeEnumMap[instance.scalingMode]!,
};

const _$ScalingModeEnumMap = {
  ScalingMode.unified: 'unified',
  ScalingMode.independent: 'independent',
  ScalingMode.autoScale: 'autoScale',
};

PlotConfiguration _$PlotConfigurationFromJson(
  Map<String, dynamic> json,
) => PlotConfiguration(
  id: json['id'] as String,
  title: json['title'] as String? ?? 'Time Series Plot',
  yAxis: json['yAxis'] == null
      ? null
      : PlotAxisConfiguration.fromJson(json['yAxis'] as Map<String, dynamic>),
  timeWindow: json['timeWindow'] == null
      ? const Duration(minutes: 5)
      : const DurationConverter().fromJson((json['timeWindow'] as num).toInt()),
);

Map<String, dynamic> _$PlotConfigurationToJson(PlotConfiguration instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'yAxis': instance.yAxis,
      'timeWindow': const DurationConverter().toJson(instance.timeWindow),
    };
