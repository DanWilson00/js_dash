/// Sealed class for different connection types
/// This provides type-safe configuration for various MAVLink data sources
sealed class ConnectionConfig {
  const ConnectionConfig();
}

/// UDP MAVLink connection configuration
class UdpConnectionConfig extends ConnectionConfig {
  final String host;
  final int port;
  
  const UdpConnectionConfig({
    required this.host,
    required this.port,
  });
  
  @override
  String toString() => 'UDP($host:$port)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UdpConnectionConfig &&
          runtimeType == other.runtimeType &&
          host == other.host &&
          port == other.port;
  
  @override
  int get hashCode => host.hashCode ^ port.hashCode;
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

/// Extension methods for easy configuration creation
extension ConnectionConfigFactory on ConnectionConfig {
  static ConnectionConfig udp({required String host, required int port}) =>
      UdpConnectionConfig(host: host, port: port);
  
  static ConnectionConfig serial({required String port, required int baudRate}) =>
      SerialConnectionConfig(port: port, baudRate: baudRate);
  
  static ConnectionConfig spoof({int systemId = 1, int componentId = 1, int baudRate = 57600}) =>
      SpoofConnectionConfig(
        systemId: systemId,
        componentId: componentId,
        baudRate: baudRate,
      );
}