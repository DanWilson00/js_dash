import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:js_dash/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:js_dash/providers/service_providers.dart';
import 'package:js_dash/mavlink/mavlink.dart';
import 'package:flutter/services.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Performance test - Dashboard & Plot interaction', (
    tester,
  ) async {
    // 1. Setup minimal dependencies
    // Load a dummy dialect to avoid file I/O issues in test
    final registry = MavlinkMetadataRegistry();
    // Use a minimal common dialect definition
    const minimalDialect = '''
    {
      "version": 1,
      "dialect": 0,
      "messages": [
        {
          "id": 0,
          "name": "HEARTBEAT",
          "fields": [
            {"name": "custom_mode", "type": "uint32_t", "units": ""},
            {"name": "type", "type": "uint8_t", "units": ""},
            {"name": "autopilot", "type": "uint8_t", "units": ""},
            {"name": "base_mode", "type": "uint8_t", "units": ""},
            {"name": "system_status", "type": "uint8_t", "units": ""}
          ]
        }
      ]
    }
    ''';
    registry.loadFromJsonString(minimalDialect);

    // 2. Start performance tracing
    await binding.traceAction(() async {
      // Build the app
      await tester.pumpWidget(
        ProviderScope(
          overrides: [mavlinkRegistryProvider.overrideWithValue(registry)],
          // Enable auto-start monitor to simulate data flow if connected
          child: const SubmersibleJetskiApp(autoStartMonitor: true),
        ),
      );

      // Wait for animations to settle (startup animation)
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 3. Interact with Dashboard
      // Find the "Telemetry" tab in the bottom navigation (index 1)
      final telemetryTab = find.byIcon(Icons.show_chart);
      if (telemetryTab.evaluate().isNotEmpty) {
        await tester.tap(telemetryTab);
        await tester.pumpAndSettle();
      }

      // 4. Simulate a busy loop or interaction
      // Drag a plot to trigger "sticky" logic and chart repaints
      // We assume a plot exists (default plot is usually added)
      final plotArea = find.byType(CustomPaint).last; // Likely the chart
      if (plotArea.evaluate().isNotEmpty) {
        await tester.drag(plotArea, const Offset(100, 0));
        await tester.pump();
        await tester.drag(plotArea, const Offset(-50, 0));
        await tester.pump();
      }

      // 5. Switch back to Dashboard to test disposal/re-init
      final dashboardTab = find.byIcon(Icons.dashboard);
      if (dashboardTab.evaluate().isNotEmpty) {
        await tester.tap(dashboardTab);
        await tester.pumpAndSettle();
      }

      // Run for a bit to capture frame stats
      await Future.delayed(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }, reportKey: 'performance_summary');
  });
}
