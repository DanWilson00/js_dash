# Modular Dashboard Architecture

## Overview
This architecture enables easy configuration and extension of dashboard widgets through a centralized configuration system.

## Core Components

### 1. Widget Configuration
```dart
class DashboardWidgetConfig {
  final String id;
  final String type;
  final GridPosition position;
  final Map<String, dynamic> properties;
  final DataBinding dataBinding;
}

class GridPosition {
  final int row;
  final int column;
  final int rowSpan;
  final int columnSpan;
}

class DataBinding {
  final String dataSource;
  final String field;
  final ValueTransformer? transformer;
}
```

### 2. Dashboard Layout Configuration
```dart
class DashboardConfig {
  final String name;
  final GridLayout layout;
  final List<DashboardWidgetConfig> widgets;
  final ThemeConfig theme;
}

class GridLayout {
  final int rows;
  final int columns;
  final double gap;
  final EdgeInsets padding;
}
```

### 3. Widget Registry
- Central registry for all available widget types
- Factory pattern for widget creation
- Plugin-style registration for custom widgets

### 4. Data Provider System
- Abstracted data sources (MAVLink, sensors, etc.)
- Observable pattern for real-time updates
- Data transformation pipeline

## Example Configuration
```dart
final jetsharkDashConfig = DashboardConfig(
  name: 'Jetshark Main',
  layout: GridLayout(rows: 3, columns: 5, gap: 16),
  widgets: [
    DashboardWidgetConfig(
      id: 'rpm_gauge',
      type: 'CircularGauge',
      position: GridPosition(row: 1, column: 2, rowSpan: 2, columnSpan: 2),
      properties: {
        'min': 0,
        'max': 7000,
        'zones': [
          {'end': 4200, 'color': Colors.blue},
          {'end': 5950, 'color': Colors.orange},
          {'end': 7000, 'color': Colors.red},
        ],
      },
      dataBinding: DataBinding(
        dataSource: 'mavlink',
        field: 'rpm',
      ),
    ),
    // ... more widgets
  ],
);
```

## Benefits
1. **Single Configuration Point**: All widget properties and placement in one place
2. **Hot Reload Friendly**: Change configs without recompiling
3. **Extensible**: Easy to add new widget types
4. **Testable**: Mock data providers for testing
5. **Reusable**: Share widgets across different dashboards