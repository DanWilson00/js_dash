import 'package:flutter/material.dart';
import '../../services/settings_manager.dart';
import '../../models/plot_configuration.dart';

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
                      const Icon(Icons.grid_view, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Plot Layout',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  dense: true,
                  title: const Text('Number of plots'),
                  subtitle: Text('${plots.plotCount} plots visible'),
                  trailing: SizedBox(
                    width: 200,
                    child: Slider(
                      value: plots.plotCount.toDouble(),
                      min: 1,
                      max: 6,
                      divisions: 5,
                      label: plots.plotCount.toString(),
                      onChanged: (value) {
                        widget.settingsManager.updatePlotCount(value.round());
                      },
                    ),
                  ),
                ),
                ListTile(
                  dense: true,
                  title: const Text('Layout style'),
                  subtitle: const Text('How plots are arranged on screen'),
                  trailing: DropdownButton<String>(
                    value: plots.layout,
                    items: _getLayoutOptions(plots.plotCount),
                    onChanged: (value) {
                      if (value != null) {
                        widget.settingsManager.updatePlotLayout(value);
                      }
                    },
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
                      const Icon(Icons.schedule, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Time Window',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  dense: true,
                  title: const Text('Default time window'),
                  subtitle: const Text('How much historical data to display'),
                  trailing: DropdownButton<String>(
                    value: plots.timeWindow,
                    items: TimeWindowOption.availableWindows
                        .map(
                          (window) => DropdownMenuItem(
                            value: window.label,
                            child: Text(window.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        widget.settingsManager.updateTimeWindow(value);
                      }
                    },
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

  List<DropdownMenuItem<String>> _getLayoutOptions(int plotCount) {
    final options = <DropdownMenuItem<String>>[];

    if (plotCount >= 1) {
      options.add(
        const DropdownMenuItem(value: 'single', child: Text('Single (1×1)')),
      );
    }

    if (plotCount >= 2) {
      options.add(
        const DropdownMenuItem(
          value: 'horizontal',
          child: Text('Horizontal (1×2)'),
        ),
      );
      options.add(
        const DropdownMenuItem(
          value: 'vertical',
          child: Text('Vertical (2×1)'),
        ),
      );
    }

    if (plotCount >= 3) {
      options.add(
        const DropdownMenuItem(value: 'grid2x2', child: Text('Grid (2×2)')),
      );
    }

    if (plotCount >= 5) {
      options.add(
        const DropdownMenuItem(value: 'grid3x2', child: Text('Grid (2×3)')),
      );
    }

    return options;
  }
}
