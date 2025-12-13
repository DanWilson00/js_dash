// Serial service with conditional imports
//
// This file exports the appropriate serial implementation based on platform:
// - Desktop (dart:io): Uses flutter_libserialport
// - Web (dart:js_interop): Uses Web Serial API
// - Other: Stub implementation

export 'serial_port_info.dart';
export 'serial_byte_source_stub.dart'
    if (dart.library.io) 'serial_byte_source_io.dart'
    if (dart.library.js_interop) 'serial_byte_source_web.dart';
