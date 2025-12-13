// UserDialectManager with conditional imports
//
// This file exports the appropriate implementation based on platform:
// - Desktop/mobile (dart:io): Full file system support
// - Web (dart:js_interop): Stub implementation (user dialects not supported)

export 'user_dialect_manager_stub.dart'
    if (dart.library.io) 'user_dialect_manager_io.dart';
