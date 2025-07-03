import 'package:flutter/material.dart';
import '../../models/plot_configuration.dart';
import '../../services/timeseries_data_manager.dart';

class MultiSignalSelectionDialog extends StatefulWidget {
  final List<PlotSignalConfiguration> currentSignals;
  final VoidCallback? onSignalsChanged;

  const MultiSignalSelectionDialog({
    super.key,
    required this.currentSignals,
    this.onSignalsChanged,
  });

  @override
  State<MultiSignalSelectionDialog> createState() => _MultiSignalSelectionDialogState();
}

class _MultiSignalSelectionDialogState extends State<MultiSignalSelectionDialog> {
  final TimeSeriesDataManager _dataManager = TimeSeriesDataManager();
  List<String> _availableFields = [];
  final Map<String, bool> _selectedFields = {};
  final Map<String, PlotSignalConfiguration> _existingSignals = {};

  @override
  void initState() {
    super.initState();
    _loadAvailableFields();
    _initializeSelection();
  }

  void _loadAvailableFields() {
    _availableFields = _dataManager.getAvailableFields();
    setState(() {});
  }

  void _initializeSelection() {
    // Build map of existing signals by field key
    for (final signal in widget.currentSignals) {
      _existingSignals[signal.fieldKey] = signal;
      _selectedFields[signal.fieldKey] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.timeline),
          const SizedBox(width: 8),
          const Text('Select Signals'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAvailableFields,
            tooltip: 'Refresh available fields',
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available MAVLink Fields (${_availableFields.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (_availableFields.isEmpty)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber, size: 48, color: Colors.orange),
                      SizedBox(height: 16),
                      Text(
                        'No MAVLink data available',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Start receiving MAVLink messages to see available fields',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _availableFields.length,
                  itemBuilder: (context, index) {
                    final fieldKey = _availableFields[index];
                    final parts = fieldKey.split('.');
                    final messageType = parts.length > 1 ? parts[0] : 'Unknown';
                    final fieldName = parts.length > 1 ? parts[1] : fieldKey;
                    final isSelected = _selectedFields[fieldKey] ?? false;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (selected) {
                          setState(() {
                            _selectedFields[fieldKey] = selected ?? false;
                          });
                        },
                        title: Text(
                          fieldName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(messageType),
                        secondary: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _getPreviewColor(fieldKey),
                            shape: BoxShape.circle,
                          ),
                        ),
                        dense: true,
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Selected: ${_getSelectedCount()}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _getSelectedCount() > 0 ? _clearAll : null,
                  child: const Text('Clear All'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _availableFields.isNotEmpty ? _selectAll : null,
                  child: const Text('Select All'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _getSelectedCount() > 0 ? _applySelection : null,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  int _getSelectedCount() {
    return _selectedFields.values.where((selected) => selected).length;
  }

  Color _getPreviewColor(String fieldKey) {
    // If signal already exists, use its color
    final existingSignal = _existingSignals[fieldKey];
    if (existingSignal != null) {
      return existingSignal.color;
    }
    
    // For new signals, calculate what color they would get
    final usedColors = <Color>{};
    int newSignalIndex = 0;
    
    // Collect colors from existing signals that are selected
    for (final entry in _selectedFields.entries) {
      if (entry.value) {
        final existing = _existingSignals[entry.key];
        if (existing != null) {
          usedColors.add(existing.color);
        } else if (entry.key != fieldKey) {
          // This is another new signal that would be processed before this one
          newSignalIndex++;
        }
      }
    }
    
    // Find next available color for this new signal
    Color previewColor = SignalColorPalette.getColorForSignal(fieldKey);
    int colorIndex = 0;
    while (usedColors.contains(previewColor) && colorIndex < SignalColorPalette.availableColors.length) {
      previewColor = SignalColorPalette.getNextColor(usedColors.length + newSignalIndex + colorIndex);
      colorIndex++;
    }
    
    return previewColor;
  }

  void _clearAll() {
    setState(() {
      _selectedFields.clear();
    });
  }

  void _selectAll() {
    setState(() {
      for (final field in _availableFields) {
        _selectedFields[field] = true;
      }
    });
  }

  void _applySelection() {
    final selectedSignals = <PlotSignalConfiguration>[];
    final usedColors = <Color>{};

    // First pass: collect existing signals and their colors
    for (final fieldKey in _availableFields) {
      if (_selectedFields[fieldKey] == true) {
        final existingSignal = _existingSignals[fieldKey];
        if (existingSignal != null) {
          selectedSignals.add(existingSignal);
          usedColors.add(existingSignal.color);
        }
      }
    }

    // Second pass: create new signals with unused colors
    for (final fieldKey in _availableFields) {
      if (_selectedFields[fieldKey] == true) {
        final existingSignal = _existingSignals[fieldKey];
        if (existingSignal == null) {
          final parts = fieldKey.split('.');
          final messageType = parts.length > 1 ? parts[0] : 'Unknown';
          final fieldName = parts.length > 1 ? parts[1] : fieldKey;
          
          // Find next available color
          Color signalColor = SignalColorPalette.getColorForSignal(fieldKey);
          int colorIndex = 0;
          while (usedColors.contains(signalColor) && colorIndex < SignalColorPalette.availableColors.length) {
            signalColor = SignalColorPalette.getNextColor(selectedSignals.length + colorIndex);
            colorIndex++;
          }
          usedColors.add(signalColor);

          final signal = PlotSignalConfiguration(
            id: '${messageType}_${fieldName}_${DateTime.now().millisecondsSinceEpoch}',
            messageType: messageType,
            fieldName: fieldName,
            color: signalColor,
          );
          selectedSignals.add(signal);
        }
      }
    }

    Navigator.of(context).pop(selectedSignals);
  }
}

// Helper function to show the dialog
Future<List<PlotSignalConfiguration>?> showMultiSignalSelectionDialog(
  BuildContext context,
  List<PlotSignalConfiguration> currentSignals,
) {
  return showDialog<List<PlotSignalConfiguration>>(
    context: context,
    builder: (context) => MultiSignalSelectionDialog(
      currentSignals: currentSignals,
    ),
  );
}