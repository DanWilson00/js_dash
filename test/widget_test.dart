// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:js_dash/main.dart';
import 'package:js_dash/services/mavlink_service.dart';
import 'package:js_dash/services/mavlink_spoof_service.dart';
import 'package:js_dash/services/mavlink_message_tracker.dart';
import 'package:js_dash/services/settings_manager.dart';

void main() {
  testWidgets('Submersible Jetski App smoke test', (WidgetTester tester) async {
    // Reset singletons before test
    MavlinkService.resetInstanceForTesting();
    MavlinkSpoofService.resetInstanceForTesting();
    MavlinkMessageTracker.resetInstanceForTesting();
    
    // Set larger test size for three-column layout
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    
    // Build our app and trigger a frame.
    final settingsManager = SettingsManager();
    await tester.pumpWidget(SubmersibleJetskiApp(
      settingsManager: settingsManager,
      autoStartMonitor: false,
    ));

    // Verify that our app starts with the connection status indicator.
    expect(find.textContaining('SPOOF MODE'), findsOneWidget);
    
    // Reset size
    await tester.binding.setSurfaceSize(null);
  });
}
