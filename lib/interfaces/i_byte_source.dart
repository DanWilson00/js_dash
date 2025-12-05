import 'dart:async';
import 'dart:typed_data';

/// Interface for byte-level data sources
/// This abstraction allows the MAVLink parser to receive bytes from different sources
/// (serial port, spoofed data, etc.) through a unified interface
abstract class IByteSource {
  /// Stream of raw bytes from the data source
  Stream<Uint8List> get bytes;

  /// Whether the source is currently connected
  bool get isConnected;

  /// Connect to the data source
  Future<void> connect();

  /// Disconnect from the data source
  Future<void> disconnect();

  /// Dispose of resources
  void dispose();
}
