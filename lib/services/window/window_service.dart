// Window service with conditional imports
//
// This file exports the appropriate window service implementation based on platform:
// - Desktop (dart:io): Uses window_manager package
// - Web (dart:js_interop): No-op implementation
// - Other: Stub implementation

export 'window_service_stub.dart'
    if (dart.library.io) 'window_service_desktop.dart'
    if (dart.library.js_interop) 'window_service_web.dart';
