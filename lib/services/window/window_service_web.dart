// Web implementation of window service
// Window management is not available on web

import 'dart:ui';

/// Web window service - all operations are no-ops
class WindowService {
  const WindowService._();
  static const WindowService instance = WindowService._();

  /// Whether window management is available
  bool get isAvailable => false;

  /// Initialize the window manager
  Future<void> initialize() async {}

  /// Set up initial window with options
  Future<void> setupWindow({
    Size? size,
    Offset? position,
    bool? maximized,
    String? title,
  }) async {
    // On web, we could potentially set document.title
    // But we skip that for now
  }

  /// Show the window
  Future<void> show() async {}

  /// Hide the window
  Future<void> hide() async {}

  /// Focus the window
  Future<void> focus() async {}

  /// Maximize the window
  Future<void> maximize() async {}

  /// Unmaximize the window
  Future<void> unmaximize() async {}

  /// Close/destroy the window
  Future<void> destroy() async {}

  /// Get current window size
  Future<Size> getSize() async => const Size(800, 600);

  /// Get current window position
  Future<Offset> getPosition() async => Offset.zero;

  /// Check if window is maximized
  Future<bool> isMaximized() async => false;

  /// Set window size
  Future<void> setSize(Size size) async {}

  /// Set window position
  Future<void> setPosition(Offset position) async {}

  /// Set prevent close behavior
  Future<void> setPreventClose(bool prevent) async {}

  /// Add a window event listener
  void addListener(WindowEventListener listener) {}

  /// Remove a window event listener
  void removeListener(WindowEventListener listener) {}
}

/// Interface for window event listeners
abstract class WindowEventListener {
  void onWindowResized() {}
  void onWindowMoved() {}
  void onWindowClose() {}
  void onWindowMaximize() {}
  void onWindowUnmaximize() {}
  void onWindowFocus() {}
  void onWindowBlur() {}
}

/// Mixin that can be used instead of WindowListener for cross-platform compatibility
mixin WindowEventMixin implements WindowEventListener {
  @override
  void onWindowResized() {}

  @override
  void onWindowMoved() {}

  @override
  void onWindowClose() {}

  @override
  void onWindowMaximize() {}

  @override
  void onWindowUnmaximize() {}

  @override
  void onWindowFocus() {}

  @override
  void onWindowBlur() {}
}
