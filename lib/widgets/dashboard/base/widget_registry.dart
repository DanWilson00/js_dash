import 'package:flutter/material.dart';
import 'dashboard_widget.dart';
import 'dashboard_config.dart';
import '../data/data_provider.dart';

/// Registry for dashboard widget types
class DashboardWidgetRegistry {
  static final DashboardWidgetRegistry _instance = DashboardWidgetRegistry._internal();
  
  factory DashboardWidgetRegistry() => _instance;
  
  DashboardWidgetRegistry._internal();
  
  final Map<String, DashboardWidgetFactory> _factories = {};
  
  /// Register a widget factory
  void register(String type, DashboardWidgetFactory factory) {
    _factories[type] = factory;
  }
  
  /// Unregister a widget factory
  void unregister(String type) {
    _factories.remove(type);
  }
  
  /// Create a widget from config
  DashboardWidget? createWidget(
    DashboardWidgetConfig config,
    DataProvider dataProvider,
  ) {
    final factory = _factories[config.type];
    if (factory == null) {
      debugPrint('Warning: No factory registered for widget type: ${config.type}');
      return null;
    }
    
    return factory(config, dataProvider);
  }
  
  /// Get all registered widget types
  Set<String> get registeredTypes => _factories.keys.toSet();
  
  /// Check if a widget type is registered
  bool isRegistered(String type) => _factories.containsKey(type);
}