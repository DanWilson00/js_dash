// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plot_tab.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlotTab _$PlotTabFromJson(Map<String, dynamic> json) => PlotTab(
  id: json['id'] as String,
  name: json['name'] as String,
  plots:
      (json['plots'] as List<dynamic>?)
          ?.map((e) => PlotConfiguration.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$PlotTabToJson(PlotTab instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'plots': instance.plots,
};
