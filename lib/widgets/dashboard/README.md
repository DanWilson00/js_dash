# Modular Dashboard Architecture

## Overview
The dashboard has been restructured to use a modular, configuration-driven architecture that makes it easy to:
- Add new widget types
- Configure widget properties and placement
- Create multiple dashboard layouts
- Test widgets independently

## Key Components

### 1. Configuration System (`base/dashboard_config.dart`)
- **DashboardConfig**: Main configuration for a dashboard
- **DashboardWidgetConfig**: Configuration for individual widgets
- **GridPosition**: Defines widget placement on grid
- **DataBinding**: Links widgets to data sources

### 2. Widget System
- **Base Classes** (`base/dashboard_widget.dart`):
  - `DashboardWidget`: Abstract base for all dashboard widgets
  - `DashboardWidgetState`: Base state with common functionality
- **Widget Registry** (`base/widget_registry.dart`): Factory pattern for widget creation
- **Standard Widgets**:
  - `CircularGaugeWidget`: RPM, speed gauges
  - `WingIndicatorWidget`: Angle/position indicators

### 3. Data Provider System (`data/`)
- **DataProvider**: Abstract interface for data sources
- **MavlinkDataProvider**: Integrates with MAVLink streams
- **MockDataProvider**: For testing without hardware

### 4. Dashboard Container (`dashboard_container.dart`)
- Renders widgets based on configuration
- Manages grid layout
- Handles responsive sizing

## Usage Example

```dart
// 1. Initialize widgets
initializeStandardWidgets();

// 2. Create data provider
final dataProvider = MavlinkDataProvider(spoofService);

// 3. Use predefined config
final dashboard = DashboardContainer(
  config: JetsharkDashboardConfig.main,
  dataProvider: dataProvider,
);
```

## Creating Custom Widgets

1. Extend `DashboardWidget`:
```dart
class MyWidget extends DashboardWidget {
  const MyWidget({
    required DashboardWidgetConfig config,
    required DataProvider dataProvider,
  }) : super(config: config, dataProvider: dataProvider);
}
```

2. Register the widget:
```dart
DashboardWidgetRegistry().register('MyWidget', (config, provider) {
  return MyWidget(config: config, dataProvider: provider);
});
```

3. Add to configuration:
```dart
DashboardWidgetConfig(
  id: 'my_widget',
  type: 'MyWidget',
  position: GridPosition(row: 0, column: 0),
  properties: {'color': Colors.blue},
  dataBinding: DataBinding(dataSource: 'mavlink', field: 'myField'),
)
```

## Configuration Structure

```dart
DashboardConfig(
  name: 'Dashboard Name',
  layout: GridLayout(
    rows: 5,          // Grid rows
    columns: 7,       // Grid columns
    gap: 16.0,       // Space between widgets
  ),
  theme: ThemeConfig(
    backgroundColor: Colors.black,
    primaryColor: Color(0xFF4a90e2),
  ),
  widgets: [
    // Widget configurations...
  ],
)
```

## Benefits
1. **Centralized Configuration**: All widget settings in one place
2. **Hot Reload**: Change configs without recompiling
3. **Reusability**: Share widgets across dashboards
4. **Testability**: Mock data providers for testing
5. **Extensibility**: Easy to add new widget types