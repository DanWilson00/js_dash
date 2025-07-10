
/// Simple service locator for dependency injection
/// Provides a centralized way to register and resolve service dependencies
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();
  
  final Map<Type, dynamic> _services = {};
  final Map<Type, dynamic Function()> _factories = {};
  final Map<Type, dynamic Function()> _singletonFactories = {};
  final Map<Type, dynamic> _singletons = {};
  
  /// Register a singleton instance
  void registerSingleton<T>(T instance) {
    _services[T] = instance;
  }
  
  /// Register a factory function that creates new instances each time
  void registerFactory<T>(T Function() factory) {
    _factories[T] = factory;
  }
  
  /// Register a lazy singleton factory (created on first access)
  void registerLazySingleton<T>(T Function() factory) {
    _singletonFactories[T] = factory;
  }
  
  /// Get a service instance
  T get<T>() {
    // Check for registered instance
    if (_services.containsKey(T)) {
      return _services[T] as T;
    }
    
    // Check for lazy singleton
    if (_singletonFactories.containsKey(T)) {
      if (!_singletons.containsKey(T)) {
        _singletons[T] = _singletonFactories[T]!();
      }
      return _singletons[T] as T;
    }
    
    // Check for factory
    if (_factories.containsKey(T)) {
      return _factories[T]!() as T;
    }
    
    throw Exception('Service of type $T is not registered');
  }
  
  /// Check if a service is registered
  bool isRegistered<T>() {
    return _services.containsKey(T) || 
           _factories.containsKey(T) || 
           _singletonFactories.containsKey(T);
  }
  
  /// Unregister a service
  void unregister<T>() {
    _services.remove(T);
    _factories.remove(T);
    _singletonFactories.remove(T);
    _singletons.remove(T);
  }
  
  /// Clear all registered services (useful for testing)
  void reset() {
    // Dispose any services that implement Disposable
    for (final service in _services.values) {
      if (service is Disposable) {
        service.dispose();
      }
    }
    for (final service in _singletons.values) {
      if (service is Disposable) {
        service.dispose();
      }
    }
    
    _services.clear();
    _factories.clear();
    _singletonFactories.clear();
    _singletons.clear();
  }
  
  /// Get all registered service types (useful for debugging)
  List<Type> getRegisteredTypes() {
    final types = <Type>{};
    types.addAll(_services.keys);
    types.addAll(_factories.keys);
    types.addAll(_singletonFactories.keys);
    return types.toList();
  }
}

/// Interface for services that need cleanup
abstract interface class Disposable {
  void dispose();
}

/// Convenience methods for accessing the service locator
class GetIt {
  static final ServiceLocator _locator = ServiceLocator();
  
  static T get<T>() => _locator.get<T>();
  static void registerSingleton<T>(T instance) => _locator.registerSingleton<T>(instance);
  static void registerFactory<T>(T Function() factory) => _locator.registerFactory<T>(factory);
  static void registerLazySingleton<T>(T Function() factory) => _locator.registerLazySingleton<T>(factory);
  static bool isRegistered<T>() => _locator.isRegistered<T>();
  static void unregister<T>() => _locator.unregister<T>();
  static void reset() => _locator.reset();
}