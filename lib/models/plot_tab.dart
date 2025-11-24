import 'package:json_annotation/json_annotation.dart';
import 'plot_configuration.dart';

part 'plot_tab.g.dart';

@JsonSerializable()
class PlotTab {
  final String id;
  final String name;
  final List<PlotConfiguration> plots;

  const PlotTab({required this.id, required this.name, this.plots = const []});

  PlotTab copyWith({String? id, String? name, List<PlotConfiguration>? plots}) {
    return PlotTab(
      id: id ?? this.id,
      name: name ?? this.name,
      plots: plots ?? this.plots,
    );
  }

  factory PlotTab.fromJson(Map<String, dynamic> json) =>
      _$PlotTabFromJson(json);

  Map<String, dynamic> toJson() => _$PlotTabToJson(this);
}
