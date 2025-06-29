# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

js_dash is a Flutter application for drone/UAV communication and telemetry display using the MAVLink protocol. The app can communicate with ArduPilot, PX4, and other MAVLink-compatible autopilots to display real-time telemetry and send commands. The intent is to use with a custom autopilot and be a dash for the vehicle. The vehicle is a submersible jetski that is piloted so we want to create a cool looking dash. There will be multiple pages or views that the user can scroll between. One will be a map, one real-time data display and plotting, potentially a settings page. 

## Development Commands

### Flutter Commands
- `flutter run` - Run the app on connected device or emulator
- `flutter run -d web` - Run on web browser
- `flutter run -d linux` - Run on Linux desktop
- `flutter build` - Build release version
- `flutter test` - Run unit tests
- `flutter analyze` - Run static analysis and linting
- `flutter clean` - Clean build artifacts
- `flutter pub get` - Install dependencies
- `flutter pub upgrade` - Upgrade dependencies

### Testing
- `flutter test` - Run all tests
- `flutter test test/widget_test.dart` - Run specific test file

## Code Architecture

### Main Application Structure
- `lib/main.dart` - Entry point with basic Flutter counter app template
- `test/widget_test.dart` - Basic widget tests

### MAVLink Interface (`interface/`)

#### Dart MAVLink Package (`interface/dart-mavlink/`)
- **Purpose**: Pure Dart implementation of MAVLink protocol for Flutter integration
- **Key Files**:
  - `lib/mavlink_parser.dart` - Stream-based MAVLink packet parser (v1/v2 support)
  - `lib/mavlink_message.dart` - Base message class with serialization
  - `lib/dialects/` - Protocol dialects (common, ardupilotmega, minimal, etc.)
  - `tool/generate.dart` - Code generator for Dart classes from XML definitions
- **Usage**: Provides `MavlinkParser` for parsing incoming packets and message classes for communication

#### C++ MAVLink Library (`interface/mavlink/`)
- **Purpose**: Standard C/C++ MAVLink implementation for embedded systems integration
- **Structure**: Generated headers organized by dialect with examples for Arduino

### Communication Architecture
The app is designed to handle MAVLink communication through:
1. **Incoming**: Transport → Parser → Frame → Message → Application UI
2. **Outgoing**: Application → Message → Frame → Serialization → Transport

### Dependencies
- `dart_mavlink: ^0.1.0` - Runtime MAVLink protocol implementation
- `cupertino_icons: ^1.0.8` - iOS-style icons
- `flutter_lints: ^5.0.0` - Dart/Flutter linting rules

## Platform Support
- **Web**: Supported via Chrome
- **Linux Desktop**: Supported
- **Android**: SDK not configured (requires Android Studio setup)
- **iOS/macOS**: Platform files present but not tested

## Development Notes
- The project includes a git submodule at `interface/dart-mavlink/mavlink/` containing the official MAVLink message definitions
- The main app is currently a Flutter template - the MAVLink integration is prepared but not yet implemented in the UI
- Code generation for MAVLink messages is handled by the `tool/generate.dart` script in the dart-mavlink package
- There are different dialects of mavlink. We are using `interface/dart-mavlink/mavlink/lib/dialects/common.dart`
- The code at `interface/mavlink` can be ignored for now
- Development should proceed with well defined modules. Each module should have a set of tests. When modules are developed, all tests should pass.
- Communication will be via USB-serial in production but we want a way to spoof the mavlink packets for testing without the need to connect to the autopilot.
- The target is a linux app