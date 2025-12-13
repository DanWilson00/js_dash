// Stub implementation of platform capabilities
// This file is used as the default when neither dart:io nor dart:html are available

class PlatformCapabilities {
  const PlatformCapabilities._();

  static const PlatformCapabilities instance = PlatformCapabilities._();

  /// Whether running in a web browser
  bool get isWeb => false;

  /// Whether native serial port access is available (desktop with flutter_libserialport)
  bool get supportsNativeSerial => false;

  /// Whether Web Serial API is available (Chrome/Edge browsers)
  bool get supportsWebSerial => false;

  /// Whether native file system access is available
  bool get supportsFileSystem => false;

  /// Whether window management is available (desktop)
  bool get supportsWindowManager => false;

  /// Human-readable platform name
  String get platformName => 'Unknown';
}
