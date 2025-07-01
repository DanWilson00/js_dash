import 'package:flutter/material.dart';
import '../models/plot_configuration.dart';
import '../services/timeseries_data_manager.dart';

class SignalSelectorPanel extends StatefulWidget {
  final List<PlotSignalConfiguration> activeSignals;
  final Function(String messageType, String fieldName) onSignalToggle;
  final ScalingMode scalingMode;
  final Function(ScalingMode) onScalingModeChanged;

  const SignalSelectorPanel({
    super.key,
    required this.activeSignals,
    required this.onSignalToggle,
    required this.scalingMode,
    required this.onScalingModeChanged,
  });

  @override
  State<SignalSelectorPanel> createState() => _SignalSelectorPanelState();
}

class _SignalSelectorPanelState extends State<SignalSelectorPanel> {
  final TimeSeriesDataManager _dataManager = TimeSeriesDataManager();
  List<String> _availableFields = [];
  Set<String> _activeFieldKeys = {};

  @override
  void initState() {
    super.initState();
    _loadAvailableFields();
    _updateActiveSignals();
  }

  @override
  void didUpdateWidget(SignalSelectorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeSignals != widget.activeSignals) {
      _updateActiveSignals();
    }
  }

  void _loadAvailableFields() {
    _availableFields = _dataManager.getAvailableFields();
    setState(() {});
  }

  void _updateActiveSignals() {
    _activeFieldKeys = widget.activeSignals.map((signal) => signal.fieldKey).toSet();
    setState(() {});
  }

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
            SizedBox(
              height: 250,
              child: _buildSignalsList(context),
            ),
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
          'Available Signals',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Text(
          '${_activeFieldKeys.length} active',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: _loadAvailableFields,
          tooltip: 'Refresh available fields',
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
          value: widget.scalingMode,
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
              widget.onScalingModeChanged(mode);
            }
          },
          isDense: true,
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: _getScalingModeTooltip(widget.scalingMode),
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
    if (_availableFields.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No MAVLink data available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start receiving MAVLink messages\\nto see available signals',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Group fields by message type for better organization
    final fieldsByMessage = <String, List<String>>{};
    for (final fieldKey in _availableFields) {
      final parts = fieldKey.split('.');
      final messageType = parts.length > 1 ? parts[0] : 'Unknown';
      final fieldName = parts.length > 1 ? parts[1] : fieldKey;
      
      fieldsByMessage.putIfAbsent(messageType, () => []).add(fieldName);
    }

    return ListView.builder(
      itemCount: fieldsByMessage.length,
      itemBuilder: (context, index) {
        final messageType = fieldsByMessage.keys.elementAt(index);
        final fields = fieldsByMessage[messageType]!;
        
        return _buildMessageTypeSection(context, messageType, fields);
      },
    );
  }

  Widget _buildMessageTypeSection(BuildContext context, String messageType, List<String> fields) {
    return ExpansionTile(
      title: Text(
        messageType,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        '${fields.length} fields',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      children: fields.map((fieldName) {
        final fieldKey = '$messageType.$fieldName';
        final isActive = _activeFieldKeys.contains(fieldKey);
        final activeSignal = widget.activeSignals
            .where((s) => s.fieldKey == fieldKey)
            .firstOrNull;

        return _buildSignalTile(
          context,
          messageType,
          fieldName,
          fieldKey,
          isActive,
          activeSignal?.color,
        );
      }).toList(),
    );
  }

  Widget _buildSignalTile(
    BuildContext context,
    String messageType,
    String fieldName,
    String fieldKey,
    bool isActive,
    Color? signalColor,
  ) {
    return ListTile(
      dense: true,
      leading: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: isActive 
              ? (signalColor ?? Theme.of(context).colorScheme.primary)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          border: isActive ? null : Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: isActive
            ? Icon(
                Icons.check,
                size: 10,
                color: Colors.white,
              )
            : null,
      ),
      title: Text(
        fieldName,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          color: isActive 
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        messageType,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      onTap: () => widget.onSignalToggle(messageType, fieldName),
      trailing: isActive
          ? Icon(
              Icons.remove_circle_outline,
              size: 20,
              color: Theme.of(context).colorScheme.error,
            )
          : Icon(
              Icons.add_circle_outline,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
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
}