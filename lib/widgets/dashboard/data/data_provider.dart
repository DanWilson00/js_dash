import 'dart:async';
import '../base/dashboard_config.dart';

/// Abstract data provider interface
abstract class DataProvider {
  /// Get a stream of data for a specific binding
  Stream<dynamic> getDataStream(DataBinding binding);
  
  /// Get current value synchronously
  dynamic getCurrentValue(DataBinding binding);
  
  /// Dispose resources
  void dispose();
}

/// Composite data provider that manages multiple data sources
class CompositeDataProvider extends DataProvider {
  final Map<String, DataProvider> _providers = {};
  
  /// Register a data provider with a source name
  void registerProvider(String sourceName, DataProvider provider) {
    _providers[sourceName] = provider;
  }
  
  /// Unregister a data provider
  void unregisterProvider(String sourceName) {
    _providers.remove(sourceName);
  }
  
  @override
  Stream<dynamic> getDataStream(DataBinding binding) {
    final provider = _providers[binding.dataSource];
    if (provider == null) {
      throw ArgumentError('No provider registered for source: ${binding.dataSource}');
    }
    
    final stream = provider.getDataStream(binding);
    
    // Apply transformer if provided
    if (binding.transformer != null) {
      return stream.map(binding.transformer!);
    }
    
    return stream;
  }
  
  @override
  dynamic getCurrentValue(DataBinding binding) {
    final provider = _providers[binding.dataSource];
    if (provider == null) {
      throw ArgumentError('No provider registered for source: ${binding.dataSource}');
    }
    
    final value = provider.getCurrentValue(binding);
    
    // Apply transformer if provided
    if (binding.transformer != null) {
      return binding.transformer!(value);
    }
    
    return value;
  }
  
  @override
  void dispose() {
    for (final provider in _providers.values) {
      provider.dispose();
    }
    _providers.clear();
  }
}

/// Mock data provider for testing
class MockDataProvider extends DataProvider {
  final Map<String, StreamController<dynamic>> _controllers = {};
  final Map<String, dynamic> _currentValues = {};
  
  /// Set a value for a field
  void setValue(String field, dynamic value) {
    _currentValues[field] = value;
    _controllers[field]?.add(value);
  }
  
  @override
  Stream<dynamic> getDataStream(DataBinding binding) {
    _controllers[binding.field] ??= StreamController<dynamic>.broadcast();
    return _controllers[binding.field]!.stream;
  }
  
  @override
  dynamic getCurrentValue(DataBinding binding) {
    return _currentValues[binding.field];
  }
  
  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
    _currentValues.clear();
  }
}