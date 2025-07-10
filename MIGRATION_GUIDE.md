# UI Component Migration Guide

This guide shows how to migrate UI components from direct service access to provider-based architecture.

## Migration Examples

### ✅ MainNavigation - COMPLETED
**Before**: Direct service instantiation
```dart
class _MainNavigationState extends State<MainNavigation> {
  final MavlinkService _mavlinkService = MavlinkService();
  final TimeSeriesDataManager _dataManager = TimeSeriesDataManager();
  // ... setState() calls, manual service management
}
```

**After**: Provider-based
```dart
class _MainNavigationState extends ConsumerState<MainNavigation> {
  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(isConnectedProvider);
    final connectionStatus = ref.watch(connectionStatusProvider);
    // ... reactive UI updates
  }
}
```

### ✅ JetsharkDashboard - COMPLETED  
**Before**: Direct TimeSeriesDataManager usage
```dart
class _JetsharkDashboardState extends State<JetsharkDashboard> {
  final TimeSeriesDataManager _dataManager = TimeSeriesDataManager();
  
  void _startDataListening() {
    _dataSubscription = _dataManager.dataStream.listen(...);
  }
}
```

**After**: Repository provider
```dart
class _JetsharkDashboardState extends ConsumerState<JetsharkDashboard> {
  void _startDataListening() {
    final repository = ref.read(telemetryRepositoryProvider);
    _dataSubscription = repository.dataStream.listen(...);
  }
}
```

### 🔄 Connection Settings Panel - EXAMPLE
**Before**: Direct settings access with setState()
```dart
class _ConnectionSettingsPanelState extends State<ConnectionSettingsPanel> {
  late TextEditingController _hostController;
  
  void _saveSettings() {
    widget.settingsManager.updateMavlinkConnection(
      _hostController.text, 
      int.parse(_portController.text)
    );
    setState(() {});
  }
}
```

**After**: Form provider with validation
```dart
class _ConnectionSettingsPanelState extends ConsumerState<ConnectionSettingsPanel> {
  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(connectionFormProvider);
    final formNotifier = ref.read(connectionFormProvider.notifier);
    
    return Column(children: [
      TextFormField(
        initialValue: formState.udpHost,
        onChanged: formNotifier.updateUdpHost,
      ),
      if (!formState.isValid) Text('Invalid configuration'),
    ]);
  }
}
```

## Migration Patterns

### 1. Convert StatefulWidget to ConsumerStatefulWidget
```dart
// Before
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}
class _MyWidgetState extends State<MyWidget> {

// After  
class MyWidget extends ConsumerStatefulWidget {
  @override
  ConsumerState<MyWidget> createState() => _MyWidgetState();
}
class _MyWidgetState extends ConsumerState<MyWidget> {
```

### 2. Replace Direct Service Access
```dart
// Before
final service = SomeService();
service.doSomething();

// After
final service = ref.read(someServiceProvider);
service.doSomething();
```

### 3. Use Reactive Data Watching
```dart
// Before
StreamSubscription subscription = service.stream.listen((data) {
  setState(() { _data = data; });
});

// After
@override
Widget build(BuildContext context) {
  final data = ref.watch(dataStreamProvider);
  return data.when(
    data: (value) => MyDataWidget(value),
    loading: () => CircularProgressIndicator(),
    error: (error, stack) => ErrorWidget(error),
  );
}
```

### 4. Replace setState with Provider Actions
```dart
// Before
void _updateSetting(String value) {
  _setting = value;
  setState(() {});
}

// After
void _updateSetting(String value) {
  ref.read(settingProvider.notifier).state = value;
  // UI automatically updates via watch
}
```

## Available Providers

### Service Providers
- `connectionManagerProvider` - Connection management
- `telemetryRepositoryProvider` - Unified data access
- `settingsManagerProvider` - Settings management

### UI State Providers
- `selectedViewIndexProvider` - Navigation state
- `connectionFormProvider` - Connection form state
- `selectedFieldsProvider` - Field selection state
- `errorStateProvider` - Global error state
- `isLoadingProvider` - Global loading state

### Stream Providers
- `connectionStatusProvider` - Connection status updates
- `telemetryDataProvider` - Real-time telemetry data
- `appSettingsProvider` - Settings changes

### Action Providers
- `connectionActionsProvider` - Connection operations
- `dataActionsProvider` - Data management operations
- `navigationActionsProvider` - Navigation actions

## Benefits Achieved

### ✅ Completed Migrations
1. **MainNavigation**: 150+ lines → 70 lines, reactive state management
2. **JetsharkDashboard**: Eliminated direct service dependencies

### 🎯 Remaining High-Priority Components
1. **RealtimeDataDisplay** - Core telemetry view
2. **InteractivePlot** - Plotting functionality  
3. **MapView** - Map functionality
4. **Settings Panels** - Configuration components

### 📈 Architecture Improvements
- **Reduced Coupling**: UI components no longer directly depend on services
- **Reactive Updates**: Automatic UI updates when data/state changes
- **Better Testing**: Providers are easily mockable for unit tests
- **Type Safety**: Compile-time validation of state and data flow
- **Performance**: Efficient re-rendering only of components that need updates

## Next Steps

1. Continue migrating remaining components following these patterns
2. Remove `settingsManager` parameter passing once settings providers are fully adopted
3. Update tests to use provider testing patterns
4. Consider adding more specialized providers for complex UI state

The architectural foundation is complete and provides a clean, maintainable, and scalable structure for continued development.