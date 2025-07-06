import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/settings_manager.dart';
import '../../services/timeseries_data_manager.dart';

class PerformanceSettingsPanel extends StatefulWidget {
  final SettingsManager settingsManager;

  const PerformanceSettingsPanel({
    super.key,
    required this.settingsManager,
  });

  @override
  State<PerformanceSettingsPanel> createState() => _PerformanceSettingsPanelState();
}

class _PerformanceSettingsPanelState extends State<PerformanceSettingsPanel> {
  final TimeSeriesDataManager _dataManager = TimeSeriesDataManager();
  late TextEditingController _updateIntervalController;
  late TextEditingController _animationDurationController;
  late TextEditingController _bufferSizeController;
  late TextEditingController _retentionController;

  // Performance metrics
  int _currentFps = 60;
  int _currentPointCount = 0;
  int _currentBufferUsage = 0;

  @override
  void initState() {
    super.initState();
    final performance = widget.settingsManager.performance;
    _updateIntervalController = TextEditingController(text: performance.updateInterval.toString());
    _animationDurationController = TextEditingController(text: performance.animationDuration.toString());
    _bufferSizeController = TextEditingController(text: performance.dataBufferSize.toString());
    _retentionController = TextEditingController(text: performance.dataRetentionMinutes.toString());
    
    // Listen to settings changes
    widget.settingsManager.addListener(_onSettingsChanged);
    
    // Update metrics periodically
    _updateMetrics();
  }

  @override
  void dispose() {
    widget.settingsManager.removeListener(_onSettingsChanged);
    _updateIntervalController.dispose();
    _animationDurationController.dispose();
    _bufferSizeController.dispose();
    _retentionController.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {
        final performance = widget.settingsManager.performance;
        _updateIntervalController.text = performance.updateInterval.toString();
        _animationDurationController.text = performance.animationDuration.toString();
        _bufferSizeController.text = performance.dataBufferSize.toString();
        _retentionController.text = performance.dataRetentionMinutes.toString();
      });
    }
  }

  void _updateMetrics() {
    if (!mounted) return;
    
    // Get current data summary
    final dataSummary = _dataManager.getDataSummary();
    int totalPoints = 0;
    int totalBufferSize = 0;
    
    for (final bufferSize in dataSummary.values) {
      totalPoints += bufferSize;
      totalBufferSize++;
    }
    
    setState(() {
      _currentPointCount = totalPoints;
      _currentBufferUsage = totalBufferSize;
      // FPS calculation would need integration with Flutter's rendering pipeline
      // For now, estimate based on update interval
      final interval = widget.settingsManager.performance.updateInterval;
      _currentFps = interval > 0 ? (1000 / interval).round() : 60;
    });
    
    // Schedule next update
    Future.delayed(const Duration(seconds: 1), _updateMetrics);
  }

  @override
  Widget build(BuildContext context) {
    final performance = widget.settingsManager.performance;
    
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
                subtitle: const Text('Reduces points for better performance when datasets are large'),
                value: performance.enablePointDecimation,
                onChanged: (value) {
                  widget.settingsManager.updatePointDecimation(enabled: value);
                },
              ),
              ListTile(
                dense: true,
                enabled: performance.enablePointDecimation,
                title: const Text('Decimation threshold'),
                subtitle: Text('Decimate when more than ${performance.decimationThreshold} points'),
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
                            widget.settingsManager.updatePointDecimation(
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
                subtitle: const Text('Limits UI update frequency for better performance'),
                value: performance.enableUpdateThrottling,
                onChanged: (value) {
                  widget.settingsManager.updateThrottling(enabled: value);
                },
              ),
              ListTile(
                dense: true,
                enabled: performance.enableUpdateThrottling,
                title: const Text('Update interval'),
                subtitle: Text('${(1000 / performance.updateInterval).toStringAsFixed(1)} FPS'),
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
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (value) {
                      final interval = int.tryParse(value);
                      if (interval != null && interval > 0 && interval <= 1000) {
                        widget.settingsManager.updateThrottling(interval: interval);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Animations',
            icon: Icons.animation,
            children: [
              SwitchListTile(
                dense: true,
                title: const Text('Smooth animations'),
                subtitle: const Text('Animate plot transitions for better visual experience'),
                value: performance.enableSmoothAnimations,
                onChanged: (value) {
                  widget.settingsManager.updateAnimations(enabled: value);
                },
              ),
              ListTile(
                dense: true,
                enabled: performance.enableSmoothAnimations,
                title: const Text('Animation duration'),
                subtitle: const Text('How long plot transitions take'),
                trailing: SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _animationDurationController,
                    enabled: performance.enableSmoothAnimations,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: Theme.of(context).textTheme.bodySmall,
                    decoration: const InputDecoration(
                      suffixText: 'ms',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (value) {
                      final duration = int.tryParse(value);
                      if (duration != null && duration >= 0 && duration <= 1000) {
                        widget.settingsManager.updateAnimations(duration: duration);
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
                subtitle: const Text('Maximum points per signal before old data is discarded'),
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
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (value) {
                      final size = int.tryParse(value);
                      if (size != null && size >= 100 && size <= 10000) {
                        widget.settingsManager.updateDataManagement(bufferSize: size);
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
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (value) {
                      final minutes = int.tryParse(value);
                      if (minutes != null && minutes >= 1 && minutes <= 60) {
                        widget.settingsManager.updateDataManagement(retentionMinutes: minutes);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPerformanceMetrics(context),
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
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  size: 24,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Live Performance Metrics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric(
                  context,
                  label: 'Update Rate',
                  value: '$_currentFps FPS',
                  icon: Icons.speed,
                ),
                _buildMetric(
                  context,
                  label: 'Total Points',
                  value: _currentPointCount.toString(),
                  icon: Icons.scatter_plot,
                ),
                _buildMetric(
                  context,
                  label: 'Active Signals',
                  value: _currentBufferUsage.toString(),
                  icon: Icons.timeline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 32,
          color: Theme.of(context).colorScheme.secondary,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}