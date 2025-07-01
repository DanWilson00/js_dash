import 'package:flutter/material.dart';
import '../models/plot_configuration.dart';
import 'interactive_plot.dart';
import 'signal_properties_panel.dart';
import 'signal_selector_panel.dart';

class PlotGridManager extends StatefulWidget {
  final VoidCallback? onFieldAssignment;

  const PlotGridManager({
    super.key,
    this.onFieldAssignment,
  });

  @override
  State<PlotGridManager> createState() => PlotGridManagerState();
}

class PlotGridManagerState extends State<PlotGridManager> {
  List<PlotConfiguration> _plots = [
    PlotConfiguration(id: 'plot_0'),
  ];
  PlotLayout _currentLayout = PlotLayout.single;
  String? _selectedPlotId;
  TimeWindowOption _currentTimeWindow = TimeWindowOption.getDefault();
  bool _showPropertiesPanel = false; // ignore: prefer_final_fields
  bool _showSelectorPanel = false; // ignore: prefer_final_fields

  @override
  void initState() {
    super.initState();
    // Auto-select the first plot when there's only one
    if (_plots.length == 1) {
      _selectedPlotId = _plots.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildControls(),
        const SizedBox(height: 8),
        if (_selectedPlotId != null && _showPropertiesPanel) ...[
          _buildSignalPropertiesPanel(),
          const SizedBox(height: 8),
        ],
        if (_selectedPlotId != null && _showSelectorPanel) ...[
          _buildSignalSelectorPanel(),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: _buildPlotGrid(),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Plots:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            DropdownButton<int>(
              value: _plots.length,
              items: List.generate(6, (index) => index + 1)
                  .map((count) => DropdownMenuItem(
                        value: count,
                        child: Text('$count'),
                      ))
                  .toList(),
              onChanged: (count) => _updatePlotCount(count ?? 1),
              isDense: true,
            ),
            Text(
              'Layout:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            DropdownButton<PlotLayout>(
              value: _currentLayout,
              items: PlotLayout.getAvailableLayouts(_plots.length)
                  .map((layout) => DropdownMenuItem(
                        value: layout,
                        child: Text(layout.toString()),
                      ))
                  .toList(),
              onChanged: (layout) {
                if (layout != null) {
                  setState(() {
                    _currentLayout = layout;
                  });
                }
              },
              isDense: true,
            ),
            Text(
              'Time:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            DropdownButton<TimeWindowOption>(
              value: _currentTimeWindow,
              items: TimeWindowOption.availableWindows
                  .map((window) => DropdownMenuItem(
                        value: window,
                        child: Text(window.label),
                      ))
                  .toList(),
              onChanged: (window) {
                if (window != null) {
                  _updateTimeWindow(window);
                }
              },
              isDense: true,
            ),
            if (_selectedPlotId != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Plot ${_getPlotIndex(_selectedPlotId!) + 1}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlotGrid() {
    // Adjust aspect ratio based on layout to ensure x-axis visibility
    double aspectRatio;
    switch (_currentLayout.type) {
      case PlotLayoutType.single:
        aspectRatio = 2.5; // Single plot can be wider
        break;
      case PlotLayoutType.horizontal:
        aspectRatio = 2.0; // Side by side plots
        break;
      case PlotLayoutType.vertical:
        aspectRatio = 2.2; // Stacked plots
        break;
      case PlotLayoutType.grid2x2:
      case PlotLayoutType.grid3x2:
        aspectRatio = 1.8; // Grid layouts need to be more compact
        break;
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _currentLayout.columns,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _plots.length,
      itemBuilder: (context, index) {
        final plot = _plots[index];
        return InteractivePlot(
          configuration: plot,
          isAxisSelected: _selectedPlotId == plot.id,
          onAxisTap: () => _selectPlot(plot.id),
          onClearAxis: () => _clearPlotAxis(plot.id),
          onLegendTap: () => _toggleSignalPanel(plot.id),
        );
      },
    );
  }

  void _updatePlotCount(int count) {
    setState(() {
      if (count > _plots.length) {
        // Add new plots
        for (int i = _plots.length; i < count; i++) {
          _plots.add(PlotConfiguration(
            id: 'plot_$i',
            timeWindow: _currentTimeWindow.duration,
          ));
        }
      } else if (count < _plots.length) {
        // Remove excess plots
        _plots = _plots.take(count).toList();
        
        // Clear selection if selected plot was removed
        if (_selectedPlotId != null && 
            !_plots.any((p) => p.id == _selectedPlotId)) {
          _selectedPlotId = null;
        }
      }

      // Update layout to match plot count
      _currentLayout = PlotLayout.getDefaultLayout(count);
      
      // Auto-select the first plot when there's only one
      if (count == 1 && _selectedPlotId == null) {
        _selectedPlotId = _plots.first.id;
      }
    });
  }

  void _updateTimeWindow(TimeWindowOption window) {
    setState(() {
      _currentTimeWindow = window;
      
      // Update all plots with new time window
      _plots = _plots.map((plot) => plot.copyWith(
        timeWindow: window.duration,
      )).toList();
    });
  }

  void _selectPlot(String plotId) {
    setState(() {
      _selectedPlotId = _selectedPlotId == plotId ? null : plotId;
    });
    
    if (widget.onFieldAssignment != null) {
      widget.onFieldAssignment!();
    }
  }

  Widget _buildSignalPropertiesPanel() {
    final selectedPlot = _plots.firstWhere((p) => p.id == _selectedPlotId);
    
    return SignalPropertiesPanel(
      signals: selectedPlot.yAxis.signals,
      scalingMode: selectedPlot.yAxis.scalingMode,
      onSignalUpdated: (updatedSignal) {
        _updateSignalInSelectedPlot(updatedSignal);
      },
      onSignalRemoved: (signalId) {
        _removeSignalFromSelectedPlot(signalId);
      },
      onAddSignals: () {
        _showSignalSelector();
      },
      onScalingModeChanged: (newMode) {
        _updateSelectedPlotScalingMode(newMode);
      },
    );
  }

  Widget _buildSignalSelectorPanel() {
    final selectedPlot = _plots.firstWhere((p) => p.id == _selectedPlotId);
    
    return SignalSelectorPanel(
      activeSignals: selectedPlot.yAxis.signals,
      scalingMode: selectedPlot.yAxis.scalingMode,
      onSignalToggle: (messageType, fieldName) {
        _toggleSignalInSelectedPlot(messageType, fieldName);
      },
      onScalingModeChanged: (newMode) {
        _updateSelectedPlotScalingMode(newMode);
      },
    );
  }


  void _updateSelectedPlotScalingMode(ScalingMode newMode) {
    if (_selectedPlotId == null) return;
    
    final plotIndex = _plots.indexWhere((p) => p.id == _selectedPlotId);
    if (plotIndex == -1) return;

    setState(() {
      _plots[plotIndex] = _plots[plotIndex].copyWith(
        yAxis: _plots[plotIndex].yAxis.copyWith(
          scalingMode: newMode,
        ),
      );
    });
  }

  void _toggleSignalPanel(String plotId) {
    setState(() {
      if (_selectedPlotId == plotId && _showPropertiesPanel) {
        // If same plot is selected and properties panel is shown, hide panel
        _showPropertiesPanel = false;
      } else {
        // Select plot and show properties panel
        _selectedPlotId = plotId;
        _showPropertiesPanel = true;
        _showSelectorPanel = false; // Hide selector panel if open
      }
    });
    
    if (widget.onFieldAssignment != null) {
      widget.onFieldAssignment!();
    }
  }

  void _showSignalSelector() {
    setState(() {
      _showSelectorPanel = !_showSelectorPanel;
      if (_showSelectorPanel) {
        _showPropertiesPanel = false; // Hide properties panel if open
      }
    });
  }

  void _updateSignalInSelectedPlot(PlotSignalConfiguration updatedSignal) {
    if (_selectedPlotId == null) return;
    
    final plotIndex = _plots.indexWhere((p) => p.id == _selectedPlotId);
    if (plotIndex == -1) return;

    setState(() {
      _plots[plotIndex] = _plots[plotIndex].updateSignal(updatedSignal);
    });
  }

  void _removeSignalFromSelectedPlot(String signalId) {
    if (_selectedPlotId == null) return;
    
    final plotIndex = _plots.indexWhere((p) => p.id == _selectedPlotId);
    if (plotIndex == -1) return;

    setState(() {
      _plots[plotIndex] = _plots[plotIndex].removeSignal(signalId);
    });
  }

  void _toggleSignalInSelectedPlot(String messageType, String fieldName) {
    if (_selectedPlotId == null) return;
    
    final plotIndex = _plots.indexWhere((p) => p.id == _selectedPlotId);
    if (plotIndex == -1) return;

    final fieldKey = '$messageType.$fieldName';
    final currentPlot = _plots[plotIndex];
    final existingSignalIndex = currentPlot.yAxis.signals
        .indexWhere((s) => s.fieldKey == fieldKey);

    setState(() {
      if (existingSignalIndex != -1) {
        // Signal exists, remove it
        final updatedSignals = List<PlotSignalConfiguration>.from(
          currentPlot.yAxis.signals
        );
        updatedSignals.removeAt(existingSignalIndex);
        
        _plots[plotIndex] = currentPlot.copyWith(
          yAxis: currentPlot.yAxis.copyWith(signals: updatedSignals),
        );
      } else {
        // Signal doesn't exist, add it
        final newSignal = PlotSignalConfiguration(
          id: '${messageType}_${fieldName}_${DateTime.now().millisecondsSinceEpoch}',
          messageType: messageType,
          fieldName: fieldName,
          color: SignalColorPalette.getNextColor(currentPlot.yAxis.signals.length),
        );
        
        _plots[plotIndex] = currentPlot.addSignal(newSignal);
      }
    });
  }

  void _clearPlotAxis(String plotId) {
    final plotIndex = _plots.indexWhere((p) => p.id == plotId);
    if (plotIndex != -1) {
      setState(() {
        _plots[plotIndex] = _plots[plotIndex].copyWith(
          yAxis: _plots[plotIndex].yAxis.clear(),
        );
      });
    }
  }

  int _getPlotIndex(String plotId) {
    return _plots.indexWhere((p) => p.id == plotId);
  }

  // Public method to toggle field in selected plot
  void assignFieldToSelectedPlot(String messageType, String fieldName) {
    if (_selectedPlotId == null) return;

    final plotIndex = _plots.indexWhere((p) => p.id == _selectedPlotId);
    if (plotIndex == -1) return;

    final fieldKey = '$messageType.$fieldName';
    final currentPlot = _plots[plotIndex];
    final existingSignalIndex = currentPlot.yAxis.signals
        .indexWhere((s) => s.fieldKey == fieldKey);

    setState(() {
      if (existingSignalIndex != -1) {
        // Signal exists, remove it
        final updatedSignals = List<PlotSignalConfiguration>.from(
          currentPlot.yAxis.signals
        );
        updatedSignals.removeAt(existingSignalIndex);
        
        _plots[plotIndex] = currentPlot.copyWith(
          yAxis: currentPlot.yAxis.copyWith(signals: updatedSignals),
        );
      } else {
        // Signal doesn't exist, add it
        final signal = PlotSignalConfiguration(
          id: '${messageType}_${fieldName}_${DateTime.now().millisecondsSinceEpoch}',
          messageType: messageType,
          fieldName: fieldName,
          color: SignalColorPalette.getNextColor(_plots[plotIndex].yAxis.signals.length),
        );
        
        _plots[plotIndex] = _plots[plotIndex].addSignal(signal);
      }
    });
    
    // Notify parent to refresh field highlighting
    if (widget.onFieldAssignment != null) {
      widget.onFieldAssignment!();
    }
  }

  // Public method to add signal to selected plot
  void addSignalToSelectedPlot(PlotSignalConfiguration signal) {
    if (_selectedPlotId == null) return;

    final plotIndex = _plots.indexWhere((p) => p.id == _selectedPlotId);
    if (plotIndex == -1) return;

    setState(() {
      _plots[plotIndex] = _plots[plotIndex].addSignal(signal);
    });
  }


  // Public method to check if a plot is selected
  bool get hasSelectedPlot => _selectedPlotId != null;

  // Public method to get selected plot info
  String? get selectedPlotInfo {
    if (_selectedPlotId == null) return null;
    final index = _getPlotIndex(_selectedPlotId!);
    return 'Plot ${index + 1}';
  }

  // Get all plotted fields across all plots
  Set<String> get allPlottedFields {
    final fields = <String>{};
    for (final plot in _plots) {
      for (final signal in plot.yAxis.signals) {
        fields.add(signal.fieldKey);
      }
    }
    return fields;
  }

  // Get fields and colors for the selected plot
  Map<String, Color> get selectedPlotFields {
    if (_selectedPlotId == null) return {};
    
    final plot = _plots.firstWhere((p) => p.id == _selectedPlotId);
    final fields = <String, Color>{};
    
    for (final signal in plot.yAxis.signals) {
      fields[signal.fieldKey] = signal.color;
    }
    
    return fields;
  }
  
  // Clear all signals from all plots
  void clearAllPlots() {
    setState(() {
      _plots = _plots.map((plot) => plot.copyWith(
        yAxis: plot.yAxis.clear(),
      )).toList();
    });
    
    // Notify parent to refresh field highlighting
    if (widget.onFieldAssignment != null) {
      widget.onFieldAssignment!();
    }
  }
}