import 'dart:async';

import 'package:flutter/material.dart';
import 'dashboard_config.dart';
import '../data/data_provider.dart';

/// Base class for all dashboard widgets
abstract class DashboardWidget extends StatefulWidget {
  final DashboardWidgetConfig config;
  final DataProvider dataProvider;

  const DashboardWidget({
    Key? key,
    required this.config,
    required this.dataProvider,
  }) : super(key: key);

  /// Override to provide widget-specific property validation
  bool validateConfig() => true;
}

/// Base state for dashboard widgets with common functionality
abstract class DashboardWidgetState<T extends DashboardWidget> extends State<T>
    with TickerProviderStateMixin {
  /// Current data value from the data provider
  dynamic currentValue;
  
  /// Stream subscription for data updates
  StreamSubscription? _dataSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToData();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToData() {
    if (widget.config.dataBinding != null) {
      _dataSubscription = widget.dataProvider
          .getDataStream(widget.config.dataBinding!)
          .listen((value) {
        setState(() {
          currentValue = value;
        });
      });
    }
  }

  /// Get a property value from the config with type safety
  T? getProperty<T>(String key, [T? defaultValue]) {
    final value = widget.config.properties[key];
    if (value is T) return value;
    return defaultValue;
  }

  /// Get required property or throw
  T getRequiredProperty<T>(String key) {
    final value = getProperty<T>(key);
    if (value == null) {
      throw ArgumentError('Required property "$key" not found in config');
    }
    return value;
  }
}

/// Widget factory for creating dashboard widgets
typedef DashboardWidgetFactory = DashboardWidget Function(
  DashboardWidgetConfig config,
  DataProvider dataProvider,
);