import 'package:flutter/material.dart';
import 'base/dashboard_config.dart';
import 'base/dashboard_widget.dart';
import 'base/widget_registry.dart';
import 'data/data_provider.dart';

/// Main dashboard container that renders widgets based on configuration
class DashboardContainer extends StatefulWidget {
  final DashboardConfig config;
  final DataProvider dataProvider;
  
  const DashboardContainer({
    Key? key,
    required this.config,
    required this.dataProvider,
  }) : super(key: key);
  
  @override
  State<DashboardContainer> createState() => _DashboardContainerState();
}

class _DashboardContainerState extends State<DashboardContainer> {
  final DashboardWidgetRegistry _registry = DashboardWidgetRegistry();
  
  @override
  Widget build(BuildContext context) {
    final theme = widget.config.theme ?? const ThemeConfig();
    
    return Container(
      color: theme.backgroundColor,
      padding: widget.config.layout.padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return _buildGrid(context, constraints, theme);
        },
      ),
    );
  }
  
  Widget _buildGrid(BuildContext context, BoxConstraints constraints, ThemeConfig theme) {
    final layout = widget.config.layout;
    
    // Calculate cell dimensions
    final availableWidth = constraints.maxWidth - (layout.columns - 1) * layout.gap;
    final availableHeight = constraints.maxHeight - (layout.rows - 1) * layout.gap;
    final cellWidth = availableWidth / layout.columns;
    final cellHeight = availableHeight / layout.rows;
    
    // Group widgets by their positions
    final widgetMap = <String, DashboardWidgetConfig>{};
    for (final widgetConfig in widget.config.widgets) {
      widgetMap[widgetConfig.id] = widgetConfig;
    }
    
    // Build grid cells
    final List<Widget> positionedWidgets = [];
    
    for (final widgetConfig in widget.config.widgets) {
      final position = widgetConfig.position;
      
      // Calculate widget bounds
      final left = position.column * (cellWidth + layout.gap);
      final top = position.row * (cellHeight + layout.gap);
      final width = cellWidth * position.columnSpan + 
                    layout.gap * (position.columnSpan - 1);
      final height = cellHeight * position.rowSpan + 
                     layout.gap * (position.rowSpan - 1);
      
      // Create widget
      final widget = _registry.createWidget(widgetConfig, this.widget.dataProvider);
      
      if (widget != null) {
        positionedWidgets.add(
          Positioned(
            left: left,
            top: top,
            width: width,
            height: height,
            child: widget,
          ),
        );
      }
    }
    
    return Stack(
      children: positionedWidgets,
    );
  }
}

/// Extension methods for easy dashboard creation
extension DashboardBuilders on DashboardConfig {
  Widget build(DataProvider dataProvider) {
    return DashboardContainer(
      config: this,
      dataProvider: dataProvider,
    );
  }
}