import 'package:flutter/material.dart';
import '../../services/settings_manager.dart';

class DisplaySettingsPanel extends StatefulWidget {
  final SettingsManager settingsManager;

  const DisplaySettingsPanel({super.key, required this.settingsManager});

  @override
  State<DisplaySettingsPanel> createState() => _DisplaySettingsPanelState();
}

class _DisplaySettingsPanelState extends State<DisplaySettingsPanel> {
  @override
  void initState() {
    super.initState();
    widget.settingsManager.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    widget.settingsManager.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final plots = widget.settingsManager.plots;
    final appearance = widget.settingsManager.appearance;

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
                          widget.settingsManager.updateAppearance(
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
          const SizedBox(height: 16),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_graph, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Default Scaling',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  dense: true,
                  title: const Text('Y-axis scaling mode'),
                  subtitle: const Text('Default scaling for new plots'),
                  trailing: DropdownButton<String>(
                    value: plots.scalingMode,
                    items: const [
                      DropdownMenuItem(
                        value: 'autoScale',
                        child: Text('Auto Scale'),
                      ),
                      DropdownMenuItem(
                        value: 'unified',
                        child: Text('Unified'),
                      ),
                      DropdownMenuItem(
                        value: 'independent',
                        child: Text('Independent'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        widget.settingsManager.updateScalingMode(value);
                      }
                    },
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
