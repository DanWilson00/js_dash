import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/app_settings.dart';
import '../../providers/service_providers.dart';

class PerformanceSettingsPanel extends ConsumerStatefulWidget {
  const PerformanceSettingsPanel({super.key});

  @override
  ConsumerState<PerformanceSettingsPanel> createState() =>
      _PerformanceSettingsPanelState();
}

class _PerformanceSettingsPanelState extends ConsumerState<PerformanceSettingsPanel> {
  late TextEditingController _updateIntervalController;
  late TextEditingController _bufferSizeController;
  late TextEditingController _retentionController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider).value ?? AppSettings.defaults();
    final performance = settings.performance;
    _updateIntervalController = TextEditingController(
      text: performance.updateInterval.toString(),
    );
    _bufferSizeController = TextEditingController(
      text: performance.dataBufferSize.toString(),
    );
    _retentionController = TextEditingController(
      text: performance.dataRetentionMinutes.toString(),
    );
  }

  @override
  void dispose() {
    _updateIntervalController.dispose();
    _bufferSizeController.dispose();
    _retentionController.dispose();
    super.dispose();
  }

  void _syncControllersIfNeeded(PerformanceSettings performance) {
    // Only update if different to avoid cursor jumping during user input
    if (_updateIntervalController.text != performance.updateInterval.toString()) {
      _updateIntervalController.text = performance.updateInterval.toString();
    }
    if (_bufferSizeController.text != performance.dataBufferSize.toString()) {
      _bufferSizeController.text = performance.dataBufferSize.toString();
    }
    if (_retentionController.text != performance.dataRetentionMinutes.toString()) {
      _retentionController.text = performance.dataRetentionMinutes.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value ?? AppSettings.defaults();
    final performance = settings.performance;

    // Sync controllers with settings (replaces listener pattern)
    _syncControllersIfNeeded(performance);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            title: 'Point Decimation',
            icon: Icons.scatter_plot,
            children: [
              SwitchListTile(
                dense: true,
                title: const Text('Enable point decimation'),
                subtitle: const Text(
                  'Reduces points for better performance when datasets are large',
                ),
                value: performance.enablePointDecimation,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).updatePointDecimation(enabled: value);
                },
              ),
              ListTile(
                dense: true,
                enabled: performance.enablePointDecimation,
                title: const Text('Decimation threshold'),
                subtitle: Text(
                  'Decimate when more than ${performance.decimationThreshold} points',
                ),
                trailing: SizedBox(
                  width: 200,
                  child: Slider(
                    value: performance.decimationThreshold.toDouble(),
                    min: 100,
                    max: 5000,
                    divisions: 49,
                    label: performance.decimationThreshold.toString(),
                    onChanged: performance.enablePointDecimation
                        ? (value) {
                            ref.read(settingsProvider.notifier).updatePointDecimation(
                              threshold: value.round(),
                            );
                          }
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Update Throttling',
            icon: Icons.timer,
            children: [
              SwitchListTile(
                dense: true,
                title: const Text('Enable update throttling'),
                subtitle: const Text(
                  'Limits UI update frequency for better performance',
                ),
                value: performance.enableUpdateThrottling,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).updateThrottling(enabled: value);
                },
              ),
              ListTile(
                dense: true,
                enabled: performance.enableUpdateThrottling,
                title: const Text('Update interval'),
                subtitle: Text(
                  '${(1000 / performance.updateInterval).toStringAsFixed(1)} FPS',
                ),
                trailing: SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _updateIntervalController,
                    enabled: performance.enableUpdateThrottling,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: Theme.of(context).textTheme.bodySmall,
                    decoration: const InputDecoration(
                      suffixText: 'ms',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (value) {
                      final interval = int.tryParse(value);
                      if (interval != null &&
                          interval > 0 &&
                          interval <= 1000) {
                        ref.read(settingsProvider.notifier).updateThrottling(
                          interval: interval,
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Data Management',
            icon: Icons.storage,
            children: [
              ListTile(
                dense: true,
                title: const Text('Buffer size'),
                subtitle: const Text(
                  'Maximum points per signal before old data is discarded',
                ),
                trailing: SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _bufferSizeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: Theme.of(context).textTheme.bodySmall,
                    decoration: const InputDecoration(
                      suffixText: 'points',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (value) {
                      final size = int.tryParse(value);
                      if (size != null && size >= 100 && size <= 10000) {
                        ref.read(settingsProvider.notifier).updateDataManagement(
                          bufferSize: size,
                        );
                      }
                    },
                  ),
                ),
              ),
              ListTile(
                dense: true,
                title: const Text('Data retention'),
                subtitle: const Text('How long to keep data in memory'),
                trailing: SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _retentionController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: Theme.of(context).textTheme.bodySmall,
                    decoration: const InputDecoration(
                      suffixText: 'minutes',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (value) {
                      final minutes = int.tryParse(value);
                      if (minutes != null && minutes >= 1 && minutes <= 60) {
                        ref.read(settingsProvider.notifier).updateDataManagement(
                          retentionMinutes: minutes,
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
