// Platform capabilities detection with conditional imports
//
// This file uses conditional imports to select the appropriate implementation
// based on the target platform:
// - dart:io available -> desktop/mobile implementation
// - dart:js_interop available -> web implementation
// - neither -> stub implementation

export 'platform_capabilities_stub.dart'
    if (dart.library.io) 'platform_capabilities_io.dart'
    if (dart.library.js_interop) 'platform_capabilities_web.dart';
