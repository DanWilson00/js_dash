import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:box_transform/box_transform.dart' as bt;
import '../../models/app_settings.dart';
import '../../models/plot_configuration.dart';
import '../../providers/service_providers.dart';
import 'interactive_plot.dart';
import 'signal_properties_panel.dart';

class PlotGridManager extends ConsumerStatefulWidget {
  final VoidCallback? onFieldAssignment;
  final String tabId;

  const PlotGridManager({
    super.key,
    this.onFieldAssignment,
    required this.tabId,
  });

  @override
  ConsumerState<PlotGridManager> createState() => PlotGridManagerState();
}

class PlotGridManagerState extends ConsumerState<PlotGridManager> {
  late List<PlotConfiguration> _plots;
  String? _selectedPlotId;
  late bool _showPropertiesPanel;

  // Canvas constraints
  Size _canvasSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _loadFromSettings();
  }

  void _loadFromSettings() {
    final settings = Settings.getInitialSettings();
    final plotSettings = settings.plots;

    final tab = plotSettings.tabs.firstWhere(
      (t) => t.id == widget.tabId,
      orElse: () => plotSettings.tabs.first,
    );

    _plots = List<PlotConfiguration>.from(tab.plots);
    _showPropertiesPanel = plotSettings.propertiesPanelVisible;

    if (_plots.isNotEmpty) {
      _selectedPlotId = _plots.first.id;
    } else {
      _selectedPlotId = null;
    }
  }

  void _addDefaultPlot({bool save = true}) {
    final newId = 'plot_${DateTime.now().millisecondsSinceEpoch}';

    final settings = ref.read(settingsProvider).value ?? AppSettings.defaults();
    final timeWindowLabel = settings.plots.timeWindow;
    final timeWindowOption = TimeWindowOption.availableWindows.firstWhere(
      (w) => w.label == timeWindowLabel,
      orElse: () => TimeWindowOption.getDefault(),
    );

    final offset = (_plots.length % 5) * 30.0;

    final newPlot = PlotConfiguration(
      id: newId,
      timeWindow: timeWindowOption.duration,
      layoutData: PlotLayoutData(
        x: offset,
        y: offset,
        width: PlotLayoutData.kDefaultWidth,
        height: PlotLayoutData.kDefaultHeight,
      ),
    );

    setState(() {
      _plots.add(newPlot);
      _selectedPlotId = newId;
    });

    if (save) {
      _saveToSettings();
    }
  }

  void _saveToSettings() {
    ref.read(settingsProvider.notifier).updatePlotsInTab(widget.tabId, _plots);
  }

  void _updatePlotLayout(String plotId, Rect newRect) {
    setState(() {
      final index = _plots.indexWhere((p) => p.id == plotId);
      if (index != -1) {
        _plots[index] = _plots[index].copyWith(
          layoutData: PlotLayoutData.fromRect(newRect),
        );
      }
    });
    _saveToSettings();
  }

  void _selectPlot(String plotId) {
    setState(() {
      _selectedPlotId = plotId;
    });
  }

  void _clearPlotAxis(String plotId) {
    setState(() {
      final index = _plots.indexWhere((p) => p.id == plotId);
      if (index != -1) {
        _plots[index] = _plots[index].copyWith(
          yAxis: _plots[index].yAxis.copyWith(signals: []),
        );
      }
    });
    _saveToSettings();
  }

  void _handleLegendTap(String plotId, PlotSignalConfiguration signal) {
    _showColorPicker(plotId, signal);
  }

  void _showColorPicker(String plotId, PlotSignalConfiguration signal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Color for ${signal.fieldName}'),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SignalColorPalette.availableColors.map((color) {
              return GestureDetector(
                onTap: () {
                  _updateSignalColor(plotId, signal.id, color);
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: signal.color == color
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.2),
                      width: signal.color == color ? 3 : 1,
                    ),
                  ),
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

  void _updateSignalColor(String plotId, String signalId, Color newColor) {
    setState(() {
      final plotIndex = _plots.indexWhere((p) => p.id == plotId);
      if (plotIndex != -1) {
        final signalIndex = _plots[plotIndex].yAxis.signals.indexWhere(
          (s) => s.id == signalId,
        );
        if (signalIndex != -1) {
          final updatedSignals = List<PlotSignalConfiguration>.from(
            _plots[plotIndex].yAxis.signals,
          );
          updatedSignals[signalIndex] = updatedSignals[signalIndex].copyWith(
            color: newColor,
          );
          _plots[plotIndex] = _plots[plotIndex].copyWith(
            yAxis: _plots[plotIndex].yAxis.copyWith(signals: updatedSignals),
          );
        }
      }
    });
    _saveToSettings();
  }

  void _removePlot(String plotId) {
    setState(() {
      _plots.removeWhere((p) => p.id == plotId);
      if (_selectedPlotId == plotId) {
        _selectedPlotId = _plots.isNotEmpty ? _plots.last.id : null;
      }
    });
    _saveToSettings();
  }

  int _getPlotIndex(String plotId) {
    return _plots.indexWhere((p) => p.id == plotId);
  }

  void _bringToFront(String plotId) {
    setState(() {
      final index = _plots.indexWhere((p) => p.id == plotId);
      if (index != -1 && index < _plots.length - 1) {
        final plot = _plots.removeAt(index);
        _plots.add(plot);
      }
    });
    _saveToSettings();
  }

  // --- Public Methods for RealtimeDataDisplay ---

  void addNewPlot() {
    _addDefaultPlot(save: true);
  }

  void clearAllPlots() {
    setState(() {
      _plots.clear();
      _selectedPlotId = null;
    });
    _saveToSettings();
  }

  void setEditMode(bool enabled) {
    // Edit mode is always enabled with the new free-form system
  }

  void updateTimeWindow(TimeWindowOption window) {
    setState(() {
      for (var i = 0; i < _plots.length; i++) {
        _plots[i] = _plots[i].copyWith(
          timeWindow: Duration(seconds: window.duration.inSeconds),
        );
      }
    });
    _saveToSettings();
  }

  void assignFieldToSelectedPlot(String messageType, String fieldName) {
    if (_selectedPlotId == null && _plots.isNotEmpty) {
      _selectedPlotId = _plots.first.id;
    }

    if (_selectedPlotId != null) {
      final index = _plots.indexWhere((p) => p.id == _selectedPlotId);
      if (index != -1) {
        final plot = _plots[index];
        final fieldKey = '$messageType.$fieldName';

        final existingSignalIndex = plot.yAxis.signals.indexWhere(
          (s) => s.fieldKey == fieldKey,
        );

        List<PlotSignalConfiguration> updatedSignals;
        if (existingSignalIndex != -1) {
          updatedSignals = List.from(plot.yAxis.signals)
            ..removeAt(existingSignalIndex);
        } else {
          final registry = ref.read(mavlinkRegistryProvider);
          final messageMetadata = registry.getMessageByName(messageType);
          final fieldMetadata = messageMetadata?.getField(fieldName);
          final units = fieldMetadata?.units;

          updatedSignals = List.from(plot.yAxis.signals)
            ..add(
              PlotSignalConfiguration(
                id: fieldKey,
                messageType: messageType,
                fieldName: fieldName,
                displayName: fieldName,
                units: units,
                color: SignalColorPalette.getNextColor(
                  plot.yAxis.signals.length,
                ),
              ),
            );
        }

        setState(() {
          _plots[index] = plot.copyWith(
            yAxis: plot.yAxis.copyWith(signals: updatedSignals),
          );
        });
        _saveToSettings();
        widget.onFieldAssignment?.call();
      }
    } else {
      addNewPlot();
      Future.microtask(() => assignFieldToSelectedPlot(messageType, fieldName));
    }
  }

  Set<String> get allPlottedFields {
    final fields = <String>{};
    for (final plot in _plots) {
      for (final signal in plot.yAxis.signals) {
        fields.add(signal.fieldKey);
      }
    }
    return fields;
  }

  Map<String, Color> get selectedPlotFields {
    if (_selectedPlotId == null) return {};
    final plot = _plots.firstWhere(
      (p) => p.id == _selectedPlotId,
      orElse: () => _plots.first,
    );
    return {
      for (final signal in plot.yAxis.signals) signal.fieldKey: signal.color,
    };
  }

  Widget _buildSignalPropertiesPanel() {
    final plot = _plots.firstWhere((p) => p.id == _selectedPlotId);
    return SignalPropertiesPanel(
      signals: plot.yAxis.signals,
      onSignalUpdated: (updatedSignal) {
        setState(() {
          final plotIndex = _plots.indexWhere((p) => p.id == plot.id);
          if (plotIndex != -1) {
            final signalIndex = _plots[plotIndex].yAxis.signals.indexWhere(
              (s) => s.id == updatedSignal.id,
            );
            if (signalIndex != -1) {
              final updatedSignals = List<PlotSignalConfiguration>.from(
                _plots[plotIndex].yAxis.signals,
              );
              updatedSignals[signalIndex] = updatedSignal;
              _plots[plotIndex] = _plots[plotIndex].copyWith(
                yAxis: _plots[plotIndex].yAxis.copyWith(
                  signals: updatedSignals,
                ),
              );
            }
          }
        });
        _saveToSettings();
      },
      onSignalRemoved: (signalId) {
        setState(() {
          final plotIndex = _plots.indexWhere((p) => p.id == plot.id);
          if (plotIndex != -1) {
            final updatedSignals = List<PlotSignalConfiguration>.from(
              _plots[plotIndex].yAxis.signals,
            )..removeWhere((s) => s.id == signalId);

            _plots[plotIndex] = _plots[plotIndex].copyWith(
              yAxis: _plots[plotIndex].yAxis.copyWith(signals: updatedSignals),
            );
          }
        });
        _saveToSettings();
      },
      onAddSignals: () {},
      scalingMode: plot.yAxis.scalingMode,
      onScalingModeChanged: (mode) {
        setState(() {
          final index = _plots.indexWhere((p) => p.id == plot.id);
          if (index != -1) {
            _plots[index] = _plots[index].copyWith(
              yAxis: _plots[index].yAxis.copyWith(scalingMode: mode),
            );
          }
        });
        _saveToSettings();
      },
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
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

              if (_plots.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_chart,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No plots yet',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Click "Add Plot" to create a new plot',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.7),
                            ),
                      ),
                    ],
                  ),
                );
              }

              return Stack(
                clipBehavior: Clip.none,
                children: _plots.map((plot) {
                  return _ResizablePlotPanel(
                    key: ValueKey(plot.id),
                    plot: plot,
                    isSelected: _selectedPlotId == plot.id,
                    canvasSize: _canvasSize,
                    otherPanelRects: _plots
                        .where((p) => p.id != plot.id)
                        .map((p) => p.layoutData.toRect())
                        .toList(),
                    onSelect: () {
                      _selectPlot(plot.id);
                      _bringToFront(plot.id);
                    },
                    onLayoutChanged: (rect) => _updatePlotLayout(plot.id, rect),
                    onRemove: () => _removePlot(plot.id),
                    onClearAxis: () => _clearPlotAxis(plot.id),
                    onLegendTap: () {
                      if (plot.yAxis.signals.isNotEmpty) {
                        if (plot.yAxis.signals.length == 1) {
                          _handleLegendTap(plot.id, plot.yAxis.signals.first);
                        } else {
                          showDialog(
                            context: context,
                            builder: (context) => SimpleDialog(
                              title: const Text('Select Signal to Edit Color'),
                              children: plot.yAxis.signals.map((signal) {
                                return SimpleDialogOption(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _handleLegendTap(plot.id, signal);
                                  },
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: signal.color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(signal.fieldName),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        }
                      }
                    },
                    plotIndex: _getPlotIndex(plot.id),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A resizable and draggable plot panel widget
class _ResizablePlotPanel extends StatefulWidget {
  final PlotConfiguration plot;
  final bool isSelected;
  final Size canvasSize;
  final VoidCallback onSelect;
  final ValueChanged<Rect> onLayoutChanged;
  final VoidCallback onRemove;
  final VoidCallback onClearAxis;
  final VoidCallback onLegendTap;
  final int plotIndex;
  final List<Rect> otherPanelRects;

  const _ResizablePlotPanel({
    super.key,
    required this.plot,
    required this.isSelected,
    required this.canvasSize,
    required this.onSelect,
    required this.onLayoutChanged,
    required this.onRemove,
    required this.onClearAxis,
    required this.onLegendTap,
    required this.plotIndex,
    required this.otherPanelRects,
  });

  @override
  State<_ResizablePlotPanel> createState() => _ResizablePlotPanelState();
}

class _ResizablePlotPanelState extends State<_ResizablePlotPanel> {
  late Rect _rect;

  static const double _handleSize = 12.0;
  static const double _handleHitArea = 20.0;
  static const double _snapThreshold = 10.0; // pixels to trigger snap
  static const double _snapGap = 4.0; // gap between snapped panels

  @override
  void initState() {
    super.initState();
    _rect = widget.plot.layoutData.toRect();
  }

  @override
  void didUpdateWidget(_ResizablePlotPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plot.layoutData != widget.plot.layoutData) {
      _rect = widget.plot.layoutData.toRect();
    }
  }

  /// Snaps a value to target if within threshold
  double _snapToValue(double value, double target, double threshold) {
    return (value - target).abs() < threshold ? target : value;
  }

  /// Clamps rect to canvas bounds and prevents overlap with other panels
  Rect _clampAndPreventOverlap(Rect proposed) {
    var left = proposed.left.clamp(0.0, widget.canvasSize.width - proposed.width);
    var top = proposed.top.clamp(0.0, widget.canvasSize.height - proposed.height);

    // Push out of any overlapping panels
    for (final other in widget.otherPanelRects) {
      final rect = Rect.fromLTWH(left, top, proposed.width, proposed.height);
      if (rect.overlaps(other)) {
        // Calculate push distances for each direction
        final pushRight = other.right - rect.left + _snapGap;
        final pushLeft = rect.right - other.left + _snapGap;
        final pushDown = other.bottom - rect.top + _snapGap;
        final pushUp = rect.bottom - other.top + _snapGap;

        // Find minimum push distance (absolute value)
        final distances = [
          (pushRight, 'right'),
          (pushLeft, 'left'),
          (pushDown, 'down'),
          (pushUp, 'up'),
        ];
        distances.sort((a, b) => a.$1.abs().compareTo(b.$1.abs()));
        final minPush = distances.first;

        // Apply the smallest push
        switch (minPush.$2) {
          case 'right':
            left = other.right + _snapGap;
          case 'left':
            left = other.left - proposed.width - _snapGap;
          case 'down':
            top = other.bottom + _snapGap;
          case 'up':
            top = other.top - proposed.height - _snapGap;
        }

        // Re-clamp after pushing
        left = left.clamp(0.0, widget.canvasSize.width - proposed.width);
        top = top.clamp(0.0, widget.canvasSize.height - proposed.height);
      }
    }

    return Rect.fromLTWH(left, top, proposed.width, proposed.height);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      var newLeft = _rect.left + details.delta.dx;
      var newTop = _rect.top + details.delta.dy;

      // Snap to canvas edges
      newLeft = _snapToValue(newLeft, 0, _snapThreshold);
      newTop = _snapToValue(newTop, 0, _snapThreshold);
      newLeft = _snapToValue(
        newLeft + _rect.width,
        widget.canvasSize.width,
        _snapThreshold,
      ) - _rect.width;
      newTop = _snapToValue(
        newTop + _rect.height,
        widget.canvasSize.height,
        _snapThreshold,
      ) - _rect.height;

      // Snap to other panel edges
      for (final other in widget.otherPanelRects) {
        // Snap left edge to other's right edge (with gap)
        newLeft = _snapToValue(newLeft, other.right + _snapGap, _snapThreshold);
        // Snap right edge to other's left edge (with gap)
        newLeft = _snapToValue(
          newLeft + _rect.width,
          other.left - _snapGap,
          _snapThreshold,
        ) - _rect.width;
        // Snap top edge to other's bottom edge (with gap)
        newTop = _snapToValue(newTop, other.bottom + _snapGap, _snapThreshold);
        // Snap bottom edge to other's top edge (with gap)
        newTop = _snapToValue(
          newTop + _rect.height,
          other.top - _snapGap,
          _snapThreshold,
        ) - _rect.height;

        // Also snap aligned edges (left-to-left, right-to-right, etc.)
        newLeft = _snapToValue(newLeft, other.left, _snapThreshold);
        newLeft = _snapToValue(
          newLeft + _rect.width,
          other.right,
          _snapThreshold,
        ) - _rect.width;
        newTop = _snapToValue(newTop, other.top, _snapThreshold);
        newTop = _snapToValue(
          newTop + _rect.height,
          other.bottom,
          _snapThreshold,
        ) - _rect.height;
      }

      // Clamp to canvas and prevent overlap
      final proposedRect = Rect.fromLTWH(newLeft, newTop, _rect.width, _rect.height);
      _rect = _clampAndPreventOverlap(proposedRect);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    widget.onLayoutChanged(_rect);
  }

  void _onResizeUpdate(DragUpdateDetails details, bt.HandlePosition handle) {
    setState(() {
      double left = _rect.left;
      double top = _rect.top;
      double right = _rect.right;
      double bottom = _rect.bottom;

      if (handle.influencesLeft) {
        left = left + details.delta.dx;
        // Snap to canvas edge
        left = _snapToValue(left, 0, _snapThreshold);
        // Snap to other panel edges
        for (final other in widget.otherPanelRects) {
          left = _snapToValue(left, other.right + _snapGap, _snapThreshold);
          left = _snapToValue(left, other.left, _snapThreshold);
        }
        left = left.clamp(0.0, right - PlotLayoutData.kMinWidth);
      }
      if (handle.influencesRight) {
        right = right + details.delta.dx;
        // Snap to canvas edge
        right = _snapToValue(right, widget.canvasSize.width, _snapThreshold);
        // Snap to other panel edges
        for (final other in widget.otherPanelRects) {
          right = _snapToValue(right, other.left - _snapGap, _snapThreshold);
          right = _snapToValue(right, other.right, _snapThreshold);
        }
        right = right.clamp(left + PlotLayoutData.kMinWidth, widget.canvasSize.width);
      }
      if (handle.influencesTop) {
        top = top + details.delta.dy;
        // Snap to canvas edge
        top = _snapToValue(top, 0, _snapThreshold);
        // Snap to other panel edges
        for (final other in widget.otherPanelRects) {
          top = _snapToValue(top, other.bottom + _snapGap, _snapThreshold);
          top = _snapToValue(top, other.top, _snapThreshold);
        }
        top = top.clamp(0.0, bottom - PlotLayoutData.kMinHeight);
      }
      if (handle.influencesBottom) {
        bottom = bottom + details.delta.dy;
        // Snap to canvas edge
        bottom = _snapToValue(bottom, widget.canvasSize.height, _snapThreshold);
        // Snap to other panel edges
        for (final other in widget.otherPanelRects) {
          bottom = _snapToValue(bottom, other.top - _snapGap, _snapThreshold);
          bottom = _snapToValue(bottom, other.bottom, _snapThreshold);
        }
        bottom = bottom.clamp(top + PlotLayoutData.kMinHeight, widget.canvasSize.height);
      }

      // Prevent overlap by checking against other panels
      final proposedRect = Rect.fromLTRB(left, top, right, bottom);
      for (final other in widget.otherPanelRects) {
        if (proposedRect.overlaps(other)) {
          // Block resize at the overlapping edge
          if (handle.influencesLeft && left < other.right && _rect.left >= other.right) {
            left = other.right + _snapGap;
          }
          if (handle.influencesRight && right > other.left && _rect.right <= other.left) {
            right = other.left - _snapGap;
          }
          if (handle.influencesTop && top < other.bottom && _rect.top >= other.bottom) {
            top = other.bottom + _snapGap;
          }
          if (handle.influencesBottom && bottom > other.top && _rect.bottom <= other.top) {
            bottom = other.top - _snapGap;
          }
        }
      }

      _rect = Rect.fromLTRB(left, top, right, bottom);
    });
  }

  void _onResizeEnd(DragEndDetails details) {
    widget.onLayoutChanged(_rect);
  }

  Widget _buildHandle(bt.HandlePosition position) {
    final isCorner = position.isDiagonal;
    final isHorizontal = position == bt.HandlePosition.left || position == bt.HandlePosition.right;

    Alignment alignment;
    switch (position) {
      case bt.HandlePosition.topLeft:
        alignment = Alignment.topLeft;
      case bt.HandlePosition.topRight:
        alignment = Alignment.topRight;
      case bt.HandlePosition.bottomLeft:
        alignment = Alignment.bottomLeft;
      case bt.HandlePosition.bottomRight:
        alignment = Alignment.bottomRight;
      case bt.HandlePosition.top:
        alignment = Alignment.topCenter;
      case bt.HandlePosition.bottom:
        alignment = Alignment.bottomCenter;
      case bt.HandlePosition.left:
        alignment = Alignment.centerLeft;
      case bt.HandlePosition.right:
        alignment = Alignment.centerRight;
      default:
        alignment = Alignment.center;
    }

    MouseCursor cursor;
    switch (position) {
      case bt.HandlePosition.topLeft:
      case bt.HandlePosition.bottomRight:
        cursor = SystemMouseCursors.resizeUpLeftDownRight;
      case bt.HandlePosition.topRight:
      case bt.HandlePosition.bottomLeft:
        cursor = SystemMouseCursors.resizeUpRightDownLeft;
      case bt.HandlePosition.top:
      case bt.HandlePosition.bottom:
        cursor = SystemMouseCursors.resizeUpDown;
      case bt.HandlePosition.left:
      case bt.HandlePosition.right:
        cursor = SystemMouseCursors.resizeLeftRight;
      default:
        cursor = SystemMouseCursors.basic;
    }

    return Align(
      alignment: alignment,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) {
            widget.onSelect();
          },
          onPanUpdate: (details) => _onResizeUpdate(details, position),
          onPanEnd: _onResizeEnd,
          child: Container(
            width: isCorner ? _handleSize : (isHorizontal ? _handleSize / 2 : _handleHitArea),
            height: isCorner ? _handleSize : (isHorizontal ? _handleHitArea : _handleSize / 2),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(isCorner ? 2 : 3),
              border: isCorner
                  ? Border.all(color: Colors.white, width: 1)
                  : null,
              boxShadow: widget.isSelected && isCorner
                  ? [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _rect.left,
      top: _rect.top,
      width: _rect.width,
      height: _rect.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main content
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  width: widget.isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isSelected
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.1),
                    blurRadius: widget.isSelected ? 12 : 4,
                    offset: const Offset(0, 2),
                    spreadRadius: widget.isSelected ? 1 : 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Column(
                  children: [
                    // Header / Drag Handle
                    GestureDetector(
                      onTap: widget.onSelect,
                      onPanStart: (_) => widget.onSelect(),
                      onPanUpdate: _onDragUpdate,
                      onPanEnd: _onDragEnd,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.move,
                        child: Container(
                          height: 28,
                          decoration: BoxDecoration(
                            color: widget.isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.1)
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(7),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.drag_indicator,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          widget.plot.yAxis.hasData
                                              ? widget.plot.yAxis.displayName
                                              : 'Plot ${widget.plotIndex + 1}',
                                          style: Theme.of(context).textTheme.labelSmall,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: widget.onRemove,
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Plot Area
                    Expanded(
                      child: InteractivePlot(
                        configuration: widget.plot,
                        isAxisSelected: widget.isSelected,
                        onAxisTap: widget.onSelect,
                        onClearAxis: widget.onClearAxis,
                        onLegendTap: widget.onLegendTap,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Resize handles (only show when selected)
          if (widget.isSelected) ...[
            _buildHandle(bt.HandlePosition.topLeft),
            _buildHandle(bt.HandlePosition.topRight),
            _buildHandle(bt.HandlePosition.bottomLeft),
            _buildHandle(bt.HandlePosition.bottomRight),
            _buildHandle(bt.HandlePosition.top),
            _buildHandle(bt.HandlePosition.bottom),
            _buildHandle(bt.HandlePosition.left),
            _buildHandle(bt.HandlePosition.right),
          ],
        ],
      ),
    );
  }
}
