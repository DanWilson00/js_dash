import 'package:flutter/material.dart';
import '../../models/plot_configuration.dart';

class SignalPropertiesPanel extends StatelessWidget {
  final List<PlotSignalConfiguration> signals;
  final Function(PlotSignalConfiguration) onSignalUpdated;
  final Function(String) onSignalRemoved;
  final Function() onAddSignals;
  final ScalingMode scalingMode;
  final Function(ScalingMode) onScalingModeChanged;

  const SignalPropertiesPanel({
    super.key,
    required this.signals,
    required this.onSignalUpdated,
    required this.onSignalRemoved,
    required this.onAddSignals,
    required this.scalingMode,
    required this.onScalingModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 12),
            _buildScalingModeSelector(context),
            const SizedBox(height: 12),
            if (signals.isNotEmpty) ...[
              _buildSignalsList(context),
            ] else
              _buildEmptyState(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.tune,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          'Signal Properties',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: onAddSignals,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: Size.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildScalingModeSelector(BuildContext context) {
    return Row(
      children: [
        Text(
          'Scaling:',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(width: 8),
        DropdownButton<ScalingMode>(
          value: scalingMode,
          items: const [
            DropdownMenuItem(
              value: ScalingMode.autoScale,
              child: Text('Auto Scale'),
            ),
            DropdownMenuItem(
              value: ScalingMode.unified,
              child: Text('Unified'),
            ),
            DropdownMenuItem(
              value: ScalingMode.independent,
              child: Text('Independent'),
            ),
          ],
          onChanged: (mode) {
            if (mode != null) {
              onScalingModeChanged(mode);
            }
          },
          isDense: true,
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: _getScalingModeTooltip(scalingMode),
          child: Icon(
            Icons.info_outline,
            size: 16,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildSignalsList(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: signals.length,
      itemBuilder: (context, index) {
        final signal = signals[index];
        return _buildSignalPropertyTile(context, signal);
      },
    );
  }

  Widget _buildSignalPropertyTile(BuildContext context, PlotSignalConfiguration signal) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ExpansionTile(
        leading: GestureDetector(
          onTap: () => _showColorPicker(context, signal),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: signal.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
                width: 1,
              ),
            ),
          ),
        ),
        title: Text(
          signal.effectiveDisplayName,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                signal.visible ? Icons.visibility : Icons.visibility_off,
                color: signal.visible 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              onPressed: () => _toggleVisibility(signal),
              tooltip: signal.visible ? 'Hide signal' : 'Show signal',
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => onSignalRemoved(signal.id),
              tooltip: 'Remove signal',
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildPropertyRow(
                  context,
                  'Display Name',
                  TextFormField(
                    initialValue: signal.displayName ?? '',
                    decoration: const InputDecoration(
                      hintText: 'Auto-generated if empty',
                      isDense: true,
                    ),
                    onChanged: (value) => _updateDisplayName(signal, value),
                  ),
                ),
                const SizedBox(height: 12),
                _buildPropertyRow(
                  context,
                  'Line Width',
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      initialValue: signal.lineWidth.toString(),
                      decoration: const InputDecoration(
                        suffixText: 'px',
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _updateLineWidth(signal, value),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildPropertyRow(
                  context,
                  'Show Dots',
                  Switch(
                    value: signal.showDots,
                    onChanged: (value) => _updateShowDots(signal, value),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyRow(BuildContext context, String label, Widget control) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: control),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.tune,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No signals to configure',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add signals to customize their appearance',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAddSignals,
            icon: const Icon(Icons.add),
            label: const Text('Add Signals'),
          ),
        ],
      ),
    );
  }

  String _getScalingModeTooltip(ScalingMode mode) {
    switch (mode) {
      case ScalingMode.autoScale:
        return 'Automatically calculate Y-axis bounds from all signal data';
      case ScalingMode.unified:
        return 'All signals share the same Y-axis scale';
      case ScalingMode.independent:
        return 'Each signal is normalized to 0-100% range';
    }
  }

  void _showColorPicker(BuildContext context, PlotSignalConfiguration signal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Choose Color for ${signal.effectiveDisplayName}'),
        content: SizedBox(
          width: 300,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SignalColorPalette.availableColors.map((color) {
              final isSelected = color == signal.color;
              return GestureDetector(
                onTap: () {
                  final updatedSignal = signal.copyWith(color: color);
                  onSignalUpdated(updatedSignal);
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _toggleVisibility(PlotSignalConfiguration signal) {
    final updatedSignal = signal.copyWith(visible: !signal.visible);
    onSignalUpdated(updatedSignal);
  }

  void _updateDisplayName(PlotSignalConfiguration signal, String value) {
    final updatedSignal = signal.copyWith(
      displayName: value.isEmpty ? null : value,
    );
    onSignalUpdated(updatedSignal);
  }

  void _updateLineWidth(PlotSignalConfiguration signal, String value) {
    final lineWidth = double.tryParse(value);
    if (lineWidth != null && lineWidth > 0) {
      final updatedSignal = signal.copyWith(lineWidth: lineWidth);
      onSignalUpdated(updatedSignal);
    }
  }

  void _updateShowDots(PlotSignalConfiguration signal, bool value) {
    final updatedSignal = signal.copyWith(showDots: value);
    onSignalUpdated(updatedSignal);
  }
}