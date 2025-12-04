import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:js_dash/core/connection_status.dart';
import 'package:js_dash/interfaces/i_connection_manager.dart';
import 'package:js_dash/interfaces/i_data_repository.dart';
import 'package:js_dash/providers/service_providers.dart';
import 'package:js_dash/providers/ui_providers.dart';
import 'package:js_dash/providers/action_providers.dart';
import 'package:js_dash/services/connection_manager.dart';
import 'package:js_dash/services/telemetry_repository.dart';
import 'package:js_dash/services/settings_manager.dart';

void main() {
  group('Service Providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should provide connection manager', () {
      final connectionManager = container.read(connectionManagerProvider);
      expect(connectionManager, isA<IConnectionManager>());
      expect(connectionManager, isA<ConnectionManager>());
    });

    test('should provide telemetry repository', () {
      final repository = container.read(telemetryRepositoryProvider);
      expect(repository, isA<IDataRepository>());
      expect(repository, isA<TelemetryRepository>());
    });

    test('should provide settings manager', () {
      final settingsManager = container.read(settingsManagerProvider);
      expect(settingsManager, isA<SettingsManager>());
    });

    test('should provide connection status stream', () {
      final statusProvider = container.read(connectionStatusProvider);
      expect(statusProvider, isA<AsyncValue<ConnectionStatus>>());
    });

    test('should provide current data source', () {
      final dataSource = container.read(currentDataSourceProvider);
      expect(dataSource, isNull); // Initially no connection
    });

    test('should provide connection state', () {
      final state = container.read(connectionStateProvider);
      expect(state, ConnectionState.disconnected);
    });

    test('should provide is connected status', () {
      final isConnected = container.read(isConnectedProvider);
      expect(isConnected, false);
    });

    test('should provide available fields', () {
      final fields = container.read(availableFieldsProvider);
      expect(fields, isA<List<String>>());
    });
  });

  group('UI Providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should provide navigation state', () {
      final viewIndex = container.read(selectedViewIndexProvider);
      expect(viewIndex, 0); // Default to first view

      // Test updating
      container.read(selectedViewIndexProvider.notifier).state = 2;
      final updatedIndex = container.read(selectedViewIndexProvider);
      expect(updatedIndex, 2);
    });

    test('should provide plot selection state', () {
      final plotIndex = container.read(selectedPlotIndexProvider);
      expect(plotIndex, 0); // Default to first plot

      // Test updating
      container.read(selectedPlotIndexProvider.notifier).state = 1;
      final updatedIndex = container.read(selectedPlotIndexProvider);
      expect(updatedIndex, 1);
    });

    test('should provide connection form state', () {
      final formState = container.read(connectionFormProvider);
      expect(formState, isA<ConnectionFormState>());
      expect(formState.serialPort, '');
      expect(formState.serialBaudRate, 115200);
      expect(formState.enableSpoofing, false);
    });

    test('should update connection form state', () {
      final notifier = container.read(connectionFormProvider.notifier);

      notifier.updateSerialPort('/dev/ttyUSB0');
      notifier.updateSerialBaudRate(57600);
      notifier.updateEnableSpoofing(true);

      final updatedState = container.read(connectionFormProvider);
      expect(updatedState.serialPort, '/dev/ttyUSB0');
      expect(updatedState.serialBaudRate, 57600);
      expect(updatedState.enableSpoofing, true);
    });

    test('should validate connection form', () {
      final notifier = container.read(connectionFormProvider.notifier);

      // Valid serial configuration
      notifier.updateSerialPort('/dev/ttyUSB0');
      notifier.updateSerialBaudRate(115200);
      expect(container.read(connectionFormProvider).isValid, true);

      // Invalid serial port (empty)
      notifier.updateSerialPort('');
      expect(container.read(connectionFormProvider).isValid, false);

      // Valid spoof configuration
      notifier.updateEnableSpoofing(true);
      notifier.updateSpoofSystemId(1);
      notifier.updateSpoofComponentId(1);
      notifier.updateSpoofBaudRate(57600);
      expect(container.read(connectionFormProvider).isValid, true);
    });

    test('should provide theme', () {
      final theme = container.read(themeProvider);
      expect(theme, isNotNull);
      expect(theme.brightness, Brightness.dark);
    });

    test('should provide field selection', () {
      final fields = container.read(selectedFieldsProvider);
      expect(fields, isEmpty);

      // Test adding fields
      container.read(selectedFieldsProvider.notifier).state = {
        'field1',
        'field2',
      };
      final updatedFields = container.read(selectedFieldsProvider);
      expect(updatedFields, {'field1', 'field2'});
    });

    test('should provide error and loading states', () {
      expect(container.read(errorStateProvider), isNull);
      expect(container.read(isLoadingProvider), false);
      expect(container.read(isPausedProvider), false);

      // Test updating states
      container.read(errorStateProvider.notifier).state = 'Test error';
      container.read(isLoadingProvider.notifier).state = true;
      container.read(isPausedProvider.notifier).state = true;

      expect(container.read(errorStateProvider), 'Test error');
      expect(container.read(isLoadingProvider), true);
      expect(container.read(isPausedProvider), true);
    });
  });

  group('Action Providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should provide connection actions', () {
      final actions = container.read(connectionActionsProvider);
      expect(actions, isA<ConnectionActions>());
    });

    test('should provide data actions', () {
      final actions = container.read(dataActionsProvider);
      expect(actions, isA<DataActions>());
    });

    test('should provide navigation actions', () {
      final actions = container.read(navigationActionsProvider);
      expect(actions, isA<NavigationActions>());
    });

    test('should handle navigation actions', () {
      final actions = container.read(navigationActionsProvider);

      // Test navigation
      actions.navigateToView(2);
      expect(container.read(selectedViewIndexProvider), 2);

      // Test plot selection
      actions.selectPlot(1);
      expect(container.read(selectedPlotIndexProvider), 1);

      // Test error handling
      actions.showError('Test error');
      expect(container.read(errorStateProvider), 'Test error');

      actions.clearError();
      expect(container.read(errorStateProvider), isNull);

      // Test loading state
      actions.setLoading(true);
      expect(container.read(isLoadingProvider), true);

      actions.setLoading(false);
      expect(container.read(isLoadingProvider), false);
    });
  });
}
