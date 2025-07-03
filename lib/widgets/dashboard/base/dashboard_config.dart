import 'package:flutter/material.dart';

/// Configuration for a single dashboard widget
class DashboardWidgetConfig {
  final String id;
  final String type;
  final GridPosition position;
  final Map<String, dynamic> properties;
  final DataBinding? dataBinding;

  const DashboardWidgetConfig({
    required this.id,
    required this.type,
    required this.position,
    this.properties = const {},
    this.dataBinding,
  });
}

/// Grid position for widget placement
class GridPosition {
  final int row;
  final int column;
  final int rowSpan;
  final int columnSpan;

  const GridPosition({
    required this.row,
    required this.column,
    this.rowSpan = 1,
    this.columnSpan = 1,
  });
}

/// Data binding configuration
class DataBinding {
  final String dataSource;
  final String field;
  final ValueTransformer? transformer;

  const DataBinding({
    required this.dataSource,
    required this.field,
    this.transformer,
  });
}

/// Transform raw data value to display value
typedef ValueTransformer = dynamic Function(dynamic value);

/// Dashboard configuration
class DashboardConfig {
  final String name;
  final GridLayout layout;
  final List<DashboardWidgetConfig> widgets;
  final ThemeConfig? theme;

  const DashboardConfig({
    required this.name,
    required this.layout,
    required this.widgets,
    this.theme,
  });
}

/// Grid layout configuration
class GridLayout {
  final int rows;
  final int columns;
  final double gap;
  final EdgeInsets padding;

  const GridLayout({
    required this.rows,
    required this.columns,
    this.gap = 8.0,
    this.padding = const EdgeInsets.all(16.0),
  });
}

/// Theme configuration for dashboard
class ThemeConfig {
  final Color backgroundColor;
  final Color primaryColor;
  final Color accentColor;
  final TextStyle? defaultTextStyle;
  final Map<String, dynamic> custom;

  const ThemeConfig({
    this.backgroundColor = Colors.black,
    this.primaryColor = const Color(0xFF4a90e2),
    this.accentColor = const Color(0xFF00ff00),
    this.defaultTextStyle,
    this.custom = const {},
  });
}