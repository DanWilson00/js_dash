import 'package:flutter/material.dart';
import '../models/plot_configuration.dart';
import 'multi_signal_selection_dialog.dart';

class SignalManagementPanel extends StatelessWidget {
  final List<PlotSignalConfiguration> signals;
  final Function(List<PlotSignalConfiguration>) onSignalsChanged;
  final Function(PlotSignalConfiguration) onSignalUpdated;
  final ScalingMode scalingMode;
  final Function(ScalingMode) onScalingModeChanged;

  const SignalManagementPanel({
    super.key,
    required this.signals,
    required this.onSignalsChanged,
    required this.onSignalUpdated,
    required this.scalingMode,
    required this.onScalingModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 8),
            if (signals.isNotEmpty) ...[
              _buildScalingModeSelector(context),
              const SizedBox(height: 8),
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
          Icons.timeline,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          'Signals (${signals.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: () => _showSignalSelectionDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Add Signals'),
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
    return Column(
      children: signals.map((signal) => _buildSignalTile(context, signal)).toList(),
    );
  }

  Widget _buildSignalTile(BuildContext context, PlotSignalConfiguration signal) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: signal.visible 
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        subtitle: Text(
          '${signal.messageType}.${signal.fieldName}',
          style: TextStyle(
            color: signal.visible 
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Theme.of(context).colorScheme.outline,
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
              onPressed: () => _toggleSignalVisibility(signal),
              tooltip: signal.visible ? 'Hide signal' : 'Show signal',
            ),
            PopupMenuButton<String>(
              onSelected: (action) => _handleSignalAction(context, signal, action),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit),
                      const SizedBox(width: 8),
                      const Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'duplicate',
                  child: Row(
                    children: [
                      const Icon(Icons.copy),
                      const SizedBox(width: 8),
                      const Text('Duplicate'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      const Icon(Icons.delete, color: Colors.red),
                      const SizedBox(width: 8),
                      const Text('Remove', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              child: Icon(
                Icons.more_vert,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
        dense: true,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.timeline,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No signals selected',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add signals to start plotting telemetry data',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
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

  void _showSignalSelectionDialog(BuildContext context) async {
    final result = await showMultiSignalSelectionDialog(context, signals);
    if (result != null) {
      onSignalsChanged(result);
    }
  }

  void _toggleSignalVisibility(PlotSignalConfiguration signal) {
    final updatedSignal = signal.copyWith(visible: !signal.visible);
    onSignalUpdated(updatedSignal);
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

  void _handleSignalAction(BuildContext context, PlotSignalConfiguration signal, String action) {
    switch (action) {
      case 'edit':
        _showEditSignalDialog(context, signal);
        break;
      case 'duplicate':
        _duplicateSignal(signal);
        break;
      case 'remove':
        _removeSignal(signal);
        break;
    }
  }

  void _showEditSignalDialog(BuildContext context, PlotSignalConfiguration signal) {
    final nameController = TextEditingController(text: signal.displayName ?? '');
    final lineWidthController = TextEditingController(text: signal.lineWidth.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${signal.effectiveDisplayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'Leave empty for auto-generated name',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: lineWidthController,
              decoration: const InputDecoration(
                labelText: 'Line Width',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Show Dots'),
              value: signal.showDots,
              onChanged: (value) {
                // This would need state management in a real implementation
                // For now, we'll keep it simple
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final lineWidth = double.tryParse(lineWidthController.text) ?? signal.lineWidth;
              final updatedSignal = signal.copyWith(
                displayName: nameController.text.isEmpty ? null : nameController.text,
                lineWidth: lineWidth,
              );
              onSignalUpdated(updatedSignal);
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _duplicateSignal(PlotSignalConfiguration signal) {
    final duplicatedSignal = PlotSignalConfiguration(
      id: '${signal.messageType}_${signal.fieldName}_${DateTime.now().millisecondsSinceEpoch}',
      messageType: signal.messageType,
      fieldName: signal.fieldName,
      units: signal.units,
      color: SignalColorPalette.getNextColor(signals.length),
      visible: signal.visible,
      displayName: signal.displayName != null ? '${signal.displayName} (Copy)' : null,
      lineWidth: signal.lineWidth,
      showDots: signal.showDots,
    );
    
    onSignalsChanged([...signals, duplicatedSignal]);
  }

  void _removeSignal(PlotSignalConfiguration signal) {
    final updatedSignals = signals.where((s) => s.id != signal.id).toList();
    onSignalsChanged(updatedSignals);
  }
}