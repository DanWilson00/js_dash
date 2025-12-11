import 'dart:async';

import '../core/connection_config.dart';
import '../core/connection_status.dart';
import '../interfaces/disposable.dart';
import '../interfaces/i_connection_manager.dart';
import '../interfaces/i_data_source.dart';
import '../mavlink/mavlink.dart';

import 'generic_message_tracker.dart';
import 'mavlink_service.dart';
import 'serial_byte_source.dart';
import 'spoof_byte_source.dart';

/// Central connection manager that handles different MAVLink data sources
/// This service abstracts connection details from UI components and provides
/// a unified interface for managing connections regardless of type
class ConnectionManager implements IConnectionManager, Disposable {
  ConnectionManager.injected(
    this._registry,
    this._injectedTracker,
  );

  final MavlinkMetadataRegistry _registry;
  final GenericMessageTracker? _injectedTracker;

  IDataSource? _currentDataSource;
  ConnectionConfig? _currentConfig;
  ConnectionState _state = ConnectionState.disconnected;
  String? _errorMessage;

  DateTime? _lastDataReceived;

  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();

  @override
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  @override
  ConnectionStatus get currentStatus => ConnectionStatus(
        state: _state,
        message: _getStateMessage(),
        timestamp: DateTime.now(),
        errorDetails: _errorMessage,
      );

  bool get isConnected => _state == ConnectionState.connected;
  bool get isConnecting => _state == ConnectionState.connecting;

  /// Get the current data source if connected
  IDataSource? get currentDataSource => _currentDataSource;

  /// Get the current connection configuration
  ConnectionConfig? get currentConfig => _currentConfig;

  /// Connect using the provided configuration
  @override
  Future<bool> connect(ConnectionConfig config) async {
    if (_state == ConnectionState.connecting) {
      return false; // Already connecting
    }

    // Disconnect existing connection if any
    if (_currentDataSource != null) {
      await disconnect();
    }

    _updateState(ConnectionState.connecting);
    _clearError();

    try {
      _currentDataSource = _createDataSource(config);
      _currentConfig = config;

      // Initialize and connect the data source
      await _currentDataSource!.initialize();
      await _currentDataSource!.connect();

      _updateState(ConnectionState.connected);
      return true;
    } catch (e) {
      _setError('Connection failed: $e');
      _currentDataSource = null;
      _currentConfig = null;
      return false;
    }
  }

  /// Disconnect from current data source
  @override
  Future<void> disconnect() async {
    if (_currentDataSource != null) {
      try {
        await _currentDataSource!.disconnect();
      } catch (e) {
        _setError('Disconnect error: $e');
      } finally {
        _currentDataSource = null;
        _currentConfig = null;
        _updateState(ConnectionState.disconnected);
      }
    }
  }

  /// Pause data collection (if supported by current data source)
  @override
  void pause() {
    if (_currentDataSource != null && _state == ConnectionState.connected) {
      _currentDataSource!.pause();
      _updateState(ConnectionState.paused);
    }
  }

  /// Resume data collection (if paused)
  @override
  void resume() {
    if (_currentDataSource != null && _state == ConnectionState.paused) {
      _currentDataSource!.resume();
      _updateState(ConnectionState.connected);
    }
  }

  /// Check if data has been received recently
  @override
  bool hasRecentData([Duration? within]) {
    if (_lastDataReceived == null) return false;
    final threshold = within ?? const Duration(seconds: 5);
    return DateTime.now().difference(_lastDataReceived!) < threshold;
  }

  /// Reconnect using the last successful configuration
  Future<bool> reconnect() async {
    if (_currentConfig != null) {
      return await connect(_currentConfig!);
    }
    return false;
  }

  /// Create appropriate data source based on configuration type
  IDataSource _createDataSource(ConnectionConfig config) {
    final tracker = _injectedTracker ?? GenericMessageTracker(_registry);

    return switch (config) {
      SerialConnectionConfig serialConfig => _createSerialService(serialConfig, tracker),
      SpoofConnectionConfig spoofConfig => _createSpoofService(spoofConfig, tracker),
    };
  }

  /// Create MAVLink service with serial byte source
  IDataSource _createSerialService(SerialConnectionConfig config, GenericMessageTracker tracker) {
    final byteSource = SerialByteSource(
      portName: config.port,
      baudRate: config.baudRate,
    );
    return MavlinkService(
      byteSource: byteSource,
      registry: _registry,
      tracker: tracker,
    );
  }

  /// Create MAVLink service with spoof byte source
  IDataSource _createSpoofService(SpoofConnectionConfig config, GenericMessageTracker tracker) {
    final byteSource = SpoofByteSource(
      registry: _registry,
      systemId: config.systemId,
      componentId: config.componentId,
    );
    return MavlinkService(
      byteSource: byteSource,
      registry: _registry,
      tracker: tracker,
    );
  }

  /// Update connection state and notify listeners
  void _updateState(ConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      final status = ConnectionStatus(
        state: _state,
        message: _getStateMessage(),
        timestamp: DateTime.now(),
        errorDetails: _errorMessage,
      );
      if (!_statusController.isClosed) {
        _statusController.add(status);
      }
    }
  }

  /// Set error message and notify listeners
  void _setError(String error) {
    _errorMessage = error;
    _updateState(ConnectionState.error);
  }

  /// Clear error message
  void _clearError() {
    _errorMessage = null;
  }

  /// Get user-friendly state message
  String _getStateMessage() {
    return switch (_state) {
      ConnectionState.disconnected => 'Disconnected',
      ConnectionState.connecting => 'Connecting...',
      ConnectionState.connected =>
        'Connected to ${_currentConfig?.toString() ?? 'unknown'}',
      ConnectionState.error => _errorMessage ?? 'Connection error',
      ConnectionState.paused => 'Paused',
    };
  }

  /// Get available serial ports (convenience method)
  static List<String> getAvailableSerialPorts() {
    return MavlinkService.getAvailableSerialPorts();
  }

  /// Create connection configurations (convenience methods)
  static ConnectionConfig createSerialConfig({
    required String port,
    int baudRate = 115200,
  }) {
    return SerialConnectionConfig(port: port, baudRate: baudRate);
  }

  static ConnectionConfig createSpoofConfig({
    int systemId = 1,
    int componentId = 1,
    int baudRate = 57600,
  }) {
    return SpoofConnectionConfig(
      systemId: systemId,
      componentId: componentId,
      baudRate: baudRate,
    );
  }

  @override
  void dispose() {
    disconnect();
    _statusController.close();
  }
}
