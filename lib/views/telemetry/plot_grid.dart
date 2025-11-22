import 'package:flutter/material.dart';
import '../../models/plot_configuration.dart';
import '../../services/settings_manager.dart';
import 'interactive_plot.dart';
import 'signal_properties_panel.dart';
import 'signal_selector_panel.dart';

class PlotGridManager extends StatefulWidget {
  final SettingsManager settingsManager;
  final VoidCallback? onFieldAssignment;

  const PlotGridManager({
    super.key,
    required this.settingsManager,
    this.onFieldAssignment,
  });

  @override
  State<PlotGridManager> createState() => PlotGridManagerState();
}

class PlotGridManagerState extends State<PlotGridManager> {
  late List<PlotConfiguration> _plots;
  String? _selectedPlotId;
  late bool _showPropertiesPanel;
  late bool _showSelectorPanel;

  // Drag and Resize state
  String? _draggingPlotId;
  String? _resizingPlotId;
  Offset? _dragStartPosition;
  PlotLayoutData? _initialLayoutData;
  Offset? _dragStartGlobalPosition;
  Offset? _resizeStartGlobalPosition;
  PlotLayoutData? _previewLayoutData;

  @override
  void initState() {
    super.initState();
    _loadFromSettings();
    if (_plots.isEmpty) {
      _addDefaultPlot();
    } else if (_plots.length == 1) {
      _selectedPlotId = _plots.first.id;
    }
  }

  void _loadFromSettings() {
    final plotSettings = widget.settingsManager.plots;
    _plots = List.from(plotSettings.configurations);
    _showPropertiesPanel = plotSettings.propertiesPanelVisible;
    _showSelectorPanel = plotSettings.selectorPanelVisible;

    final selectedIndex = plotSettings.selectedPlotIndex;
    if (selectedIndex < _plots.length && selectedIndex >= 0) {
      _selectedPlotId = _plots[selectedIndex].id;
    }
  }

  void _addDefaultPlot() {
    setState(() {
      _plots.add(
        PlotConfiguration(
          id: 'plot_${DateTime.now().millisecondsSinceEpoch}',
          layoutData: const PlotLayoutData(x: 0, y: 0, width: 0.5, height: 0.5),
        ),
      );
    });
    _saveToSettings();
  }

  void _saveToSettings() {
    final selectedIndex = _selectedPlotId != null
        ? _plots.indexWhere((plot) => plot.id == _selectedPlotId)
        : 0;

    widget.settingsManager.updatePlots(
      widget.settingsManager.plots.copyWith(
        plotCount: _plots.length,
        configurations: _plots,
        selectedPlotIndex: selectedIndex.clamp(0, _plots.length - 1),
        propertiesPanelVisible: _showPropertiesPanel,
        selectorPanelVisible: _showSelectorPanel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_selectedPlotId != null && _showPropertiesPanel) ...[
          _buildSignalPropertiesPanel(),
          const SizedBox(height: 8),
        ],
        if (_selectedPlotId != null && _showSelectorPanel) ...[
          _buildSignalSelectorPanel(),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // Background grid or placeholder if needed
                  if (_plots.isEmpty)
                    Center(
                      child: Text(
                        'No plots. Click "New Plot" to add one.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),

                  // Ghost Preview (if dragging)
                  if (_draggingPlotId != null && _previewLayoutData != null)
                    _buildGhostPreview(context, constraints),

                  // Render all plots
                  ..._plots.map(
                    (plot) => _buildDraggablePlot(context, plot, constraints),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDraggablePlot(
    BuildContext context,
    PlotConfiguration plot,
    BoxConstraints constraints,
  ) {
    // If this plot is being dragged, render it at its initial position
    // The ghost preview will show the final snapped position
    final layout = (_draggingPlotId == plot.id && _initialLayoutData != null)
        ? _initialLayoutData!
        : plot.layoutData;

    final pixelX = layout.x * constraints.maxWidth;
    final pixelY = layout.y * constraints.maxHeight;
    final pixelWidth = layout.width * constraints.maxWidth;
    final pixelHeight = layout.height * constraints.maxHeight;

    final isSelected = _selectedPlotId == plot.id;

    return Positioned(
      left: pixelX,
      top: pixelY,
      width: pixelWidth,
      height: pixelHeight,
      child: GestureDetector(
        onTapDown: (_) => _selectPlot(plot.id),
        child: Stack(
          children: [
            // The Plot Content
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag Handle (Header)
                  GestureDetector(
                    onPanStart: (details) => _onDragStart(plot, details),
                    onPanUpdate: (details) =>
                        _onDragUpdate(plot, details, constraints),
                    onPanEnd: (_) => _onDragEnd(),
                    child: Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.1)
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(7),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          Icon(
                            Icons.drag_indicator,
                            size: 16,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              plot.yAxis.hasData
                                  ? ''
                                  : 'Plot ${_getPlotIndex(plot.id) + 1}',
                              style: Theme.of(context).textTheme.labelSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Close Button
                          InkWell(
                            onTap: () => _removePlot(plot.id),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                  // Plot Area
                  Expanded(
                    child: InteractivePlot(
                      configuration: plot,
                      settingsManager: widget.settingsManager,
                      isAxisSelected: isSelected,
                      onAxisTap: () => _selectPlot(plot.id),
                      onClearAxis: () => _clearPlotAxis(plot.id),
                      onLegendTap: () => _toggleSignalPanel(plot.id),
                    ),
                  ),
                ],
              ),
            ),

            // Resize Handle (Bottom Right)
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onPanStart: (details) => _onResizeStart(plot, details),
                onPanUpdate: (details) =>
                    _onResizeUpdate(plot, details, constraints),
                onPanEnd: (_) => _onResizeEnd(),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: Icon(
                    Icons.north_west, // Arrow pointing to corner
                    size: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Drag Logic ---

  void _onDragStart(PlotConfiguration plot, DragStartDetails details) {
    setState(() {
      _draggingPlotId = plot.id;
      _initialLayoutData = plot.layoutData;
      _dragStartGlobalPosition = details.globalPosition;
      _previewLayoutData =
          plot.layoutData; // Initialize preview to current position
      _selectPlot(plot.id);
    });
  }

  void _onDragUpdate(
    PlotConfiguration plot,
    DragUpdateDetails details,
    BoxConstraints constraints,
  ) {
    if (_draggingPlotId != plot.id ||
        _initialLayoutData == null ||
        _dragStartGlobalPosition == null)
      return;

    // Calculate TOTAL delta from drag start (not incremental)
    final totalDeltaX =
        (details.globalPosition.dx - _dragStartGlobalPosition!.dx) /
        constraints.maxWidth;
    final totalDeltaY =
        (details.globalPosition.dy - _dragStartGlobalPosition!.dy) /
        constraints.maxHeight;

    // Calculate raw new position
    var rawX = (_initialLayoutData!.x + totalDeltaX).clamp(
      0.0,
      1.0 - _initialLayoutData!.width,
    );
    var rawY = (_initialLayoutData!.y + totalDeltaY).clamp(
      0.0,
      1.0 - _initialLayoutData!.height,
    );

    // Snap to grid (24 columns/rows)
    const gridSize = 1.0 / 24.0;
    final snappedX = (rawX / gridSize).round() * gridSize;
    final snappedY = (rawY / gridSize).round() * gridSize;

    // Create preview layout with snapped position
    setState(() {
      _previewLayoutData = _initialLayoutData!.copyWith(
        x: snappedX,
        y: snappedY,
      );
    });
  }

  void _onDragEnd() {
    // Apply preview position to actual plot
    if (_draggingPlotId != null && _previewLayoutData != null) {
      final index = _plots.indexWhere((p) => p.id == _draggingPlotId);
      if (index != -1) {
        setState(() {
          _plots[index] = _plots[index].copyWith(
            layoutData: _previewLayoutData!,
          );
        });
      }
    }

    setState(() {
      _draggingPlotId = null;
      _initialLayoutData = null;
      _dragStartGlobalPosition = null;
      _previewLayoutData = null;
    });
    _saveToSettings();
  }

  // --- Resize Logic ---

  void _onResizeStart(PlotConfiguration plot, DragStartDetails details) {
    setState(() {
      _resizingPlotId = plot.id;
      _initialLayoutData = plot.layoutData;
      _resizeStartGlobalPosition = details.globalPosition;
      _selectPlot(plot.id);
    });
  }

  void _onResizeUpdate(
    PlotConfiguration plot,
    DragUpdateDetails details,
    BoxConstraints constraints,
  ) {
    if (_resizingPlotId != plot.id ||
        _initialLayoutData == null ||
        _resizeStartGlobalPosition == null)
      return;

    // Calculate TOTAL delta from resize start (not incremental)
    final totalDeltaWidth =
        (details.globalPosition.dx - _resizeStartGlobalPosition!.dx) /
        constraints.maxWidth;
    final totalDeltaHeight =
        (details.globalPosition.dy - _resizeStartGlobalPosition!.dy) /
        constraints.maxHeight;

    // Minimum size constraints (e.g., 10% of screen)
    final minSize = 0.1;

    // Apply total delta to INITIAL size
    final newWidth = (_initialLayoutData!.width + totalDeltaWidth).clamp(
      minSize,
      1.0 - _initialLayoutData!.x,
    );
    final newHeight = (_initialLayoutData!.height + totalDeltaHeight).clamp(
      minSize,
      1.0 - _initialLayoutData!.y,
    );

    setState(() {
      final index = _plots.indexWhere((p) => p.id == plot.id);
      if (index != -1) {
        _plots[index] = _plots[index].copyWith(
          layoutData: _initialLayoutData!.copyWith(
            width: newWidth,
            height: newHeight,
          ),
        );
      }
    });
  }

  void _onResizeEnd() {
    setState(() {
      _resizingPlotId = null;
      _initialLayoutData = null;
      _resizeStartGlobalPosition = null;
    });
    _saveToSettings();
  }

  // --- Plot Management ---

  void addNewPlot() {
    // Find a spot? For now just add at 0,0 or offset slightly
    final count = _plots.length;
    final offset = (count * 0.05) % 0.5;

    setState(() {
      _plots.add(
        PlotConfiguration(
          id: 'plot_${DateTime.now().millisecondsSinceEpoch}',
          layoutData: PlotLayoutData(
            x: offset,
            y: offset,
            width: 0.4,
            height: 0.3,
          ),
          timeWindow: _plots.isNotEmpty
              ? _plots.first.timeWindow
              : const Duration(seconds: 10),
        ),
      );
      _selectedPlotId = _plots.last.id;
    });
    _saveToSettings();
  }

  void _removePlot(String plotId) {
    setState(() {
      _plots.removeWhere((p) => p.id == plotId);
      if (_selectedPlotId == plotId) {
        _selectedPlotId = null;
      }
    });
    _saveToSettings();
  }

  void updateTimeWindow(TimeWindowOption window) {
    setState(() {
      _plots = _plots
          .map((plot) => plot.copyWith(timeWindow: window.duration))
          .toList();
    });
    _saveToSettings();
  }

  // --- Selection & Properties ---

  void _selectPlot(String plotId) {
    if (_selectedPlotId == plotId) return;

    setState(() {
      _selectedPlotId = plotId;
      // Bring to front?
      final plot = _plots.firstWhere((p) => p.id == plotId);
      _plots.removeWhere((p) => p.id == plotId);
      _plots.add(plot);
    });
    _saveToSettings();
    widget.onFieldAssignment?.call();
  }

  void _clearPlotAxis(String plotId) {
    final index = _plots.indexWhere((p) => p.id == plotId);
    if (index != -1) {
      setState(() {
        _plots[index] = _plots[index].copyWith(
          yAxis: _plots[index].yAxis.clear(),
        );
      });
      _saveToSettings();
    }
  }

  void _toggleSignalPanel(String plotId) {
    setState(() {
      if (_selectedPlotId == plotId && _showPropertiesPanel) {
        _showPropertiesPanel = false;
      } else {
        _selectedPlotId = plotId;
        _showPropertiesPanel = true;
        _showSelectorPanel = false;

        // Bring to front
        final plot = _plots.firstWhere((p) => p.id == plotId);
        _plots.removeWhere((p) => p.id == plotId);
        _plots.add(plot);
      }
    });
    _saveToSettings();
    widget.onFieldAssignment?.call();
  }

  int _getPlotIndex(String plotId) => _plots.indexWhere((p) => p.id == plotId);

  // --- Public API for Parent ---

  void assignFieldToSelectedPlot(String messageType, String fieldName) {
    if (_selectedPlotId == null) return;
    final index = _plots.indexWhere((p) => p.id == _selectedPlotId);
    if (index == -1) return;

    final fieldKey = '$messageType.$fieldName';
    final currentPlot = _plots[index];
    final existingIndex = currentPlot.yAxis.signals.indexWhere(
      (s) => s.fieldKey == fieldKey,
    );

    setState(() {
      if (existingIndex != -1) {
        final updatedSignals = List<PlotSignalConfiguration>.from(
          currentPlot.yAxis.signals,
        );
        updatedSignals.removeAt(existingIndex);
        _plots[index] = currentPlot.copyWith(
          yAxis: currentPlot.yAxis.copyWith(signals: updatedSignals),
        );
      } else {
        final usedColors = _plots[index].yAxis.signals
            .map((s) => s.color)
            .toList();
        final signal = PlotSignalConfiguration(
          id: '${messageType}_${fieldName}_${DateTime.now().millisecondsSinceEpoch}',
          messageType: messageType,
          fieldName: fieldName,
          color: SignalColorPalette.getNextAvailableColor(usedColors),
        );
        _plots[index] = _plots[index].addSignal(signal);
      }
    });
    _saveToSettings();
    widget.onFieldAssignment?.call();
  }

  void clearAllPlots() {
    setState(() {
      _plots = _plots.map((p) => p.copyWith(yAxis: p.yAxis.clear())).toList();
    });
    _saveToSettings();
    widget.onFieldAssignment?.call();
  }

  Set<String> get allPlottedFields {
    return _plots.expand((p) => p.yAxis.signals).map((s) => s.fieldKey).toSet();
  }

  Map<String, Color> get selectedPlotFields {
    if (_selectedPlotId == null) return {};
    final plot = _plots.firstWhere(
      (p) => p.id == _selectedPlotId,
      orElse: () => _plots.first,
    );
    return {for (var s in plot.yAxis.signals) s.fieldKey: s.color};
  }

  // --- Helper Widgets ---

  Widget _buildSignalPropertiesPanel() {
    final selectedPlot = _plots.firstWhere((p) => p.id == _selectedPlotId);
    return SignalPropertiesPanel(
      signals: selectedPlot.yAxis.signals,
      scalingMode: selectedPlot.yAxis.scalingMode,
      onSignalUpdated: (updated) {
        final index = _plots.indexWhere((p) => p.id == _selectedPlotId);
        setState(() => _plots[index] = _plots[index].updateSignal(updated));
        _saveToSettings();
      },
      onSignalRemoved: (id) {
        final index = _plots.indexWhere((p) => p.id == _selectedPlotId);
        setState(() => _plots[index] = _plots[index].removeSignal(id));
        _saveToSettings();
      },
      onAddSignals: _showSignalSelector,
      onScalingModeChanged: (mode) {
        final index = _plots.indexWhere((p) => p.id == _selectedPlotId);
        setState(
          () => _plots[index] = _plots[index].copyWith(
            yAxis: _plots[index].yAxis.copyWith(scalingMode: mode),
          ),
        );
        _saveToSettings();
      },
    );
  }

  Widget _buildSignalSelectorPanel() {
    final selectedPlot = _plots.firstWhere((p) => p.id == _selectedPlotId);
    return SignalSelectorPanel(
      activeSignals: selectedPlot.yAxis.signals,
      scalingMode: selectedPlot.yAxis.scalingMode,
      onSignalToggle: (msg, field) => assignFieldToSelectedPlot(msg, field),
      onScalingModeChanged: (mode) {
        final index = _plots.indexWhere((p) => p.id == _selectedPlotId);
        setState(
          () => _plots[index] = _plots[index].copyWith(
            yAxis: _plots[index].yAxis.copyWith(scalingMode: mode),
          ),
        );
        _saveToSettings();
      },
    );
  }

  void _showSignalSelector() {
    setState(() {
      _showSelectorPanel = !_showSelectorPanel;
      if (_showSelectorPanel) _showPropertiesPanel = false;
    });
    _saveToSettings();
  }

  Widget _buildGhostPreview(BuildContext context, BoxConstraints constraints) {
    if (_previewLayoutData == null) return const SizedBox.shrink();

    final layout = _previewLayoutData!;
    final pixelX = layout.x * constraints.maxWidth;
    final pixelY = layout.y * constraints.maxHeight;
    final pixelWidth = layout.width * constraints.maxWidth;
    final pixelHeight = layout.height * constraints.maxHeight;

    return Positioned(
      left: pixelX,
      top: pixelY,
      width: pixelWidth,
      height: pixelHeight,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Stack(
            children: [
              // Corner markers
              ...[
                Alignment.topLeft,
                Alignment.topRight,
                Alignment.bottomLeft,
                Alignment.bottomRight,
              ].map(
                (alignment) => Align(
                  alignment: alignment,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              // Center crosshair
              Center(
                child: Icon(
                  Icons.add,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
