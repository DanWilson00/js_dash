import 'package:flutter/material.dart';
import '../models/plot_configuration.dart';
import 'interactive_plot.dart';

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildControls(),
        const SizedBox(height: 8),
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
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _currentLayout.columns,
        childAspectRatio: 1.8, // More square-ish to prevent cutoff
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

  // Public method to assign field to selected plot
  void assignFieldToSelectedPlot(String messageType, String fieldName) {
    if (_selectedPlotId == null) return;

    final plotIndex = _plots.indexWhere((p) => p.id == _selectedPlotId);
    if (plotIndex == -1) return;

    setState(() {
      _plots[plotIndex] = _plots[plotIndex].copyWith(
        yAxis: _plots[plotIndex].yAxis.copyWith(
          messageType: messageType,
          fieldName: fieldName,
        ),
      );
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
}