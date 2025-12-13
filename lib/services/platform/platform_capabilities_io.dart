// Desktop/mobile implementation of platform capabilities
// Uses dart:io to detect platform

import 'dart:io' show Platform;

class PlatformCapabilities {
  const PlatformCapabilities._();

  static const PlatformCapabilities instance = PlatformCapabilities._();

  /// Whether running in a web browser
  bool get isWeb => false;

  /// Whether native serial port access is available (desktop with flutter_libserialport)
  /// flutter_libserialport supports Windows, Linux, and macOS
  bool get supportsNativeSerial =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Whether Web Serial API is available (Chrome/Edge browsers)
  bool get supportsWebSerial => false;

  /// Whether native file system access is available
  bool get supportsFileSystem => true;

  /// Whether window management is available (desktop)
  bool get supportsWindowManager =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Human-readable platform name
  String get platformName {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }
}
