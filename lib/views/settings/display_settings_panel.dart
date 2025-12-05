import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/service_providers.dart';

class DisplaySettingsPanel extends ConsumerWidget {
  const DisplaySettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsManager = ref.watch(settingsManagerProvider);
    final appearance = settingsManager.appearance;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.palette, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'UI Appearance',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  dense: true,
                  title: const Text('UI Scale'),
                  subtitle: Text(
                    'Adjust the size of UI elements (${(appearance.uiScale * 100).round()}%)',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      Slider(
                        value: appearance.uiScale,
                        min: 0.6,
                        max: 1.4,
                        divisions: 8,
                        label: '${(appearance.uiScale * 100).round()}%',
                        onChanged: (value) {
                          settingsManager.updateAppearance(
                            appearance.copyWith(uiScale: value),
                          );
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '60%',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '100%',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '140%',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
