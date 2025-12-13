/// Sealed class for different connection types
/// This provides type-safe configuration for various MAVLink data sources
sealed class ConnectionConfig {
  const ConnectionConfig();
}

/// Serial MAVLink connection configuration
class SerialConnectionConfig extends ConnectionConfig {
  final String port;
  final int baudRate;

  const SerialConnectionConfig({
    required this.port,
    required this.baudRate,
  });

  @override
  String toString() => 'Serial($port@$baudRate)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SerialConnectionConfig &&
          runtimeType == other.runtimeType &&
          port == other.port &&
          baudRate == other.baudRate;

  @override
  int get hashCode => port.hashCode ^ baudRate.hashCode;
}

/// Spoof connection configuration
class SpoofConnectionConfig extends ConnectionConfig {
  final int systemId;
  final int componentId;
  final int baudRate;

  const SpoofConnectionConfig({
    this.systemId = 1,
    this.componentId = 1,
    this.baudRate = 57600,
  });

  @override
  String toString() => 'Spoof(sys:$systemId,comp:$componentId@$baudRate)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpoofConnectionConfig &&
          runtimeType == other.runtimeType &&
          systemId == other.systemId &&
          componentId == other.componentId &&
          baudRate == other.baudRate;

  @override
  int get hashCode => systemId.hashCode ^ componentId.hashCode ^ baudRate.hashCode;
}

/// Web Serial connection configuration (for Chrome/Edge browsers)
class WebSerialConnectionConfig extends ConnectionConfig {
  final int baudRate;
  final int? vendorId;
  final int? productId;

  const WebSerialConnectionConfig({
    required this.baudRate,
    this.vendorId,
    this.productId,
  });

  @override
  String toString() => 'WebSerial(@$baudRate)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebSerialConnectionConfig &&
          runtimeType == other.runtimeType &&
          baudRate == other.baudRate &&
          vendorId == other.vendorId &&
          productId == other.productId;

  @override
  int get hashCode => baudRate.hashCode ^ vendorId.hashCode ^ productId.hashCode;
}

/// Extension methods for easy configuration creation
extension ConnectionConfigFactory on ConnectionConfig {
  static ConnectionConfig serial({required String port, required int baudRate}) =>
      SerialConnectionConfig(port: port, baudRate: baudRate);

  static ConnectionConfig spoof({int systemId = 1, int componentId = 1, int baudRate = 57600}) =>
      SpoofConnectionConfig(
        systemId: systemId,
        componentId: componentId,
        baudRate: baudRate,
      );

  static ConnectionConfig webSerial({required int baudRate, int? vendorId, int? productId}) =>
      WebSerialConnectionConfig(
        baudRate: baudRate,
        vendorId: vendorId,
        productId: productId,
      );
}
