// Desktop implementation of window service
// Uses window_manager package for native window management

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Desktop window service using window_manager
class WindowService {
  WindowService._();
  static final WindowService instance = WindowService._();

  /// Whether window management is available
  bool get isAvailable => true;

  /// Initialize the window manager
  Future<void> initialize() async {
    await windowManager.ensureInitialized();
  }

  /// Set up initial window with options
  Future<void> setupWindow({
    Size? size,
    Offset? position,
    bool? maximized,
    String? title,
  }) async {
    WindowOptions windowOptions = WindowOptions(
      size: size ?? const Size(1280, 720),
      center: position == null,
      backgroundColor: Colors.transparent,
      title: title ?? 'Application',
      titleBarStyle: TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();

      // Restore window position if available
      if (position != null) {
        await windowManager.setPosition(position);
      }

      // Restore maximized state
      if (maximized == true) {
        await windowManager.maximize();
      }
    });
  }

  /// Show the window
  Future<void> show() async {
    await windowManager.show();
  }

  /// Hide the window
  Future<void> hide() async {
    await windowManager.hide();
  }

  /// Focus the window
  Future<void> focus() async {
    await windowManager.focus();
  }

  /// Maximize the window
  Future<void> maximize() async {
    await windowManager.maximize();
  }

  /// Unmaximize the window
  Future<void> unmaximize() async {
    await windowManager.unmaximize();
  }

  /// Close/destroy the window
  Future<void> destroy() async {
    await windowManager.destroy();
  }

  /// Get current window size
  Future<Size> getSize() async {
    return await windowManager.getSize();
  }

  /// Get current window position
  Future<Offset> getPosition() async {
    return await windowManager.getPosition();
  }

  /// Check if window is maximized
  Future<bool> isMaximized() async {
    return await windowManager.isMaximized();
  }

  /// Set window size
  Future<void> setSize(Size size) async {
    await windowManager.setSize(size);
  }

  /// Set window position
  Future<void> setPosition(Offset position) async {
    await windowManager.setPosition(position);
  }

  /// Set prevent close behavior
  Future<void> setPreventClose(bool prevent) async {
    await windowManager.setPreventClose(prevent);
  }

  /// Add a window event listener
  void addListener(WindowEventListener listener) {
    windowManager.addListener(_WindowListenerAdapter(listener));
  }

  /// Remove a window event listener
  void removeListener(WindowEventListener listener) {
    // Note: window_manager doesn't support removing specific listeners easily
    // This is a limitation we accept for now
  }
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

/// Adapter to bridge WindowEventListener to window_manager's WindowListener
class _WindowListenerAdapter with WindowListener {
  final WindowEventListener _listener;

  _WindowListenerAdapter(this._listener);

  @override
  void onWindowResized() => _listener.onWindowResized();

  @override
  void onWindowMoved() => _listener.onWindowMoved();

  @override
  void onWindowClose() => _listener.onWindowClose();

  @override
  void onWindowMaximize() => _listener.onWindowMaximize();

  @override
  void onWindowUnmaximize() => _listener.onWindowUnmaximize();

  @override
  void onWindowFocus() => _listener.onWindowFocus();

  @override
  void onWindowBlur() => _listener.onWindowBlur();
}
