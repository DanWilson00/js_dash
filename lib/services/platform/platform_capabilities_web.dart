// Web implementation of platform capabilities
// Uses dart:js_interop to detect browser capabilities

import 'dart:js_interop';

@JS('navigator.serial')
external JSObject? get _navigatorSerial;

class PlatformCapabilities {
  const PlatformCapabilities._();

  static const PlatformCapabilities instance = PlatformCapabilities._();

  /// Whether running in a web browser
  bool get isWeb => true;

  /// Whether native serial port access is available (desktop with flutter_libserialport)
  bool get supportsNativeSerial => false;

  /// Whether Web Serial API is available (Chrome/Edge browsers)
  bool get supportsWebSerial => _navigatorSerial != null;

  /// Whether native file system access is available
  bool get supportsFileSystem => false;

  /// Whether window management is available (desktop)
  bool get supportsWindowManager => false;

  /// Human-readable platform name
  String get platformName => 'Web';
}
