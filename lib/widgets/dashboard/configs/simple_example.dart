import 'package:flutter/material.dart';
import '../base/dashboard_config.dart';

/// Example of how easy it is to create new dashboard configurations
class SimpleDashboardConfigs {
  
  /// Single RPM gauge centered
  static DashboardConfig get singleGauge => DashboardConfig(
    name: 'Simple RPM',
    layout: const GridLayout(rows: 1, columns: 1),
    widgets: [
      DashboardWidgetConfig(
        id: 'rpm',
        type: 'CircularGauge',
        position: const GridPosition(row: 0, column: 0),
        properties: const {
          'minValue': 0,
          'maxValue': 7000,
          'label': 'ENGINE RPM',
          'zones': [
            {'end': 5000, 'color': Colors.green},
            {'end': 6000, 'color': Colors.orange},
            {'end': 7000, 'color': Colors.red},
          ],
        },
        dataBinding: const DataBinding(
          dataSource: 'mavlink',
          field: 'rpm',
        ),
      ),
    ],
  );
  
  /// Two gauges side by side
  static DashboardConfig get dualGauges => DashboardConfig(
    name: 'Dual Display',
    layout: const GridLayout(rows: 1, columns: 2, gap: 20),
    widgets: [
      DashboardWidgetConfig(
        id: 'rpm',
        type: 'CircularGauge',
        position: const GridPosition(row: 0, column: 0),
        properties: const {
          'minValue': 0,
          'maxValue': 7000,
          'label': 'RPM',
        },
        dataBinding: const DataBinding(
          dataSource: 'mavlink',
          field: 'rpm',
        ),
      ),
      DashboardWidgetConfig(
        id: 'speed',
        type: 'CircularGauge',
        position: const GridPosition(row: 0, column: 1),
        properties: const {
          'minValue': 0,
          'maxValue': 100,
          'label': 'SPEED',
          'units': 'km/h',
        },
        dataBinding: const DataBinding(
          dataSource: 'mavlink',
          field: 'speed',
        ),
      ),
    ],
  );
  
  /// Wing indicators only
  static DashboardConfig get wingIndicators => DashboardConfig(
    name: 'Wing Status',
    layout: const GridLayout(rows: 1, columns: 2),
    widgets: [
      DashboardWidgetConfig(
        id: 'left_wing',
        type: 'WingIndicator',
        position: const GridPosition(row: 0, column: 0),
        properties: const {
          'isLeft': true,
          'label': 'PORT',
        },
        dataBinding: const DataBinding(
          dataSource: 'mavlink',
          field: 'leftWingAngle',
        ),
      ),
      DashboardWidgetConfig(
        id: 'right_wing',
        type: 'WingIndicator',
        position: const GridPosition(row: 0, column: 1),
        properties: const {
          'isLeft': false,
          'label': 'STARBOARD',
        },
        dataBinding: const DataBinding(
          dataSource: 'mavlink',
          field: 'rightWingAngle',
        ),
      ),
    ],
  );
}