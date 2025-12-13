// Serial port information data class
// Used by both desktop and web serial implementations

/// Information about an available serial port
class SerialPortInfo {
  /// System-specific port identifier (e.g., "COM3" on Windows, "/dev/ttyUSB0" on Linux)
  final String portName;

  /// Human-readable description of the port (if available)
  final String? description;

  /// USB vendor ID (if USB device)
  final int? vendorId;

  /// USB product ID (if USB device)
  final int? productId;

  /// USB serial number (if available)
  final String? serialNumber;

  const SerialPortInfo({
    required this.portName,
    this.description,
    this.vendorId,
    this.productId,
    this.serialNumber,
  });

  @override
  String toString() => description ?? portName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SerialPortInfo &&
          runtimeType == other.runtimeType &&
          portName == other.portName;

  @override
  int get hashCode => portName.hashCode;
}
