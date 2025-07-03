import 'package:flutter/material.dart';
import '../base/dashboard_config.dart';

/// Jetshark dashboard configuration
class JetsharkDashboardConfig {
  static DashboardConfig get main => DashboardConfig(
    name: 'Jetshark Main Dashboard',
    layout: const GridLayout(
      rows: 5,
      columns: 7,
      gap: 16.0,
      padding: EdgeInsets.all(20.0),
    ),
    theme: const ThemeConfig(
      backgroundColor: Color(0xFF0a0a0a),
      primaryColor: Color(0xFF4a90e2),
      accentColor: Color(0xFF00ff00),
    ),
    widgets: [
      // Left Wing Indicator
      DashboardWidgetConfig(
        id: 'left_wing',
        type: 'WingIndicator',
        position: const GridPosition(
          row: 1,
          column: 0,
          rowSpan: 3,
          columnSpan: 2,
        ),
        properties: const {
          'minValue': -20.0,
          'maxValue': 20.0,
          'isLeft': true,
          'label': 'LEFT WING',
          'units': '°',
          'warningThreshold': 15.0,
          'dangerThreshold': 18.0,
        },
        dataBinding: const DataBinding(
          dataSource: 'mavlink',
          field: 'leftWingAngle',
        ),
      ),
      
      // Central RPM Gauge
      DashboardWidgetConfig(
        id: 'rpm_gauge',
        type: 'CircularGauge',
        position: const GridPosition(
          row: 0,
          column: 2,
          rowSpan: 4,
          columnSpan: 3,
        ),
        properties: const {
          'minValue': 0,
          'maxValue': 7000,
          'label': 'RPM',
          'units': 'RPM',
          'tickInterval': 1000,
          'showValue': true,
          'zones': [
            {'start': 0, 'end': 4200, 'color': Color(0xFF4a90e2)},
            {'start': 4200, 'end': 5950, 'color': Color(0xFFffa500)},
            {'start': 5950, 'end': 7000, 'color': Color(0xFFff0000)},
          ],
        },
        dataBinding: const DataBinding(
          dataSource: 'mavlink',
          field: 'rpm',
        ),
      ),
      
      // Right Wing Indicator
      DashboardWidgetConfig(
        id: 'right_wing',
        type: 'WingIndicator',
        position: const GridPosition(
          row: 1,
          column: 5,
          rowSpan: 3,
          columnSpan: 2,
        ),
        properties: const {
          'minValue': -20.0,
          'maxValue': 20.0,
          'isLeft': false,
          'label': 'RIGHT WING',
          'units': '°',
          'warningThreshold': 15.0,
          'dangerThreshold': 18.0,
        },
        dataBinding: const DataBinding(
          dataSource: 'mavlink',
          field: 'rightWingAngle',
        ),
      ),
      
      // Speed Display (inside RPM gauge)
      // Note: This would need a custom widget or be integrated into the gauge
      
      // Header/Branding can be added as a separate widget type
    ],
  );
  
  /// Alternative compact configuration
  static DashboardConfig get compact => DashboardConfig(
    name: 'Jetshark Compact',
    layout: const GridLayout(
      rows: 3,
      columns: 5,
      gap: 8.0,
      padding: EdgeInsets.all(12.0),
    ),
    theme: const ThemeConfig(
      backgroundColor: Colors.black,
      primaryColor: Color(0xFF4a90e2),
    ),
    widgets: [
      // Simplified layout with just RPM in center
      DashboardWidgetConfig(
        id: 'rpm_only',
        type: 'CircularGauge',
        position: const GridPosition(
          row: 0,
          column: 1,
          rowSpan: 3,
          columnSpan: 3,
        ),
        properties: const {
          'minValue': 0,
          'maxValue': 7000,
          'label': 'ENGINE',
          'units': 'RPM',
          'tickInterval': 1000,
          'zones': [
            {'start': 0, 'end': 5000, 'color': Color(0xFF00ff00)},
            {'start': 5000, 'end': 6500, 'color': Color(0xFFffff00)},
            {'start': 6500, 'end': 7000, 'color': Color(0xFFff0000)},
          ],
        },
        dataBinding: const DataBinding(
          dataSource: 'mavlink',
          field: 'rpm',
        ),
      ),
    ],
  );
}