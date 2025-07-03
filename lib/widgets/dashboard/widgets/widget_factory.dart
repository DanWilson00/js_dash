import '../base/widget_registry.dart';
import '../base/dashboard_config.dart';
import '../data/data_provider.dart';
import 'circular_gauge_widget.dart';
import 'wing_indicator_widget.dart';

/// Initialize standard dashboard widgets
void initializeStandardWidgets() {
  final registry = DashboardWidgetRegistry();
  
  // Register circular gauge widget
  registry.register('CircularGauge', (config, dataProvider) {
    return CircularGaugeWidget(
      config: config,
      dataProvider: dataProvider,
    );
  });
  
  // Register wing indicator widget
  registry.register('WingIndicator', (config, dataProvider) {
    return WingIndicatorWidget(
      config: config,
      dataProvider: dataProvider,
    );
  });
  
  // Register more widgets as they are created...
}