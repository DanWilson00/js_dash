import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dashboard/dashboard.dart';
import '../../models/plot_configuration.dart';
import '../../services/settings_manager.dart';
import 'interactive_plot.dart';
import 'signal_properties_panel.dart';

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

  late DashboardItemController _itemController;

  @override
  void initState() {
    super.initState();
    _loadFromSettings();
    _initializeController();
  }

  void _loadFromSettings() {
    final plotSettings = widget.settingsManager.plots;
    // Load plots from settings
    _plots = List<PlotConfiguration>.from(plotSettings.configurations);
    _showPropertiesPanel = plotSettings.propertiesPanelVisible;

    // Restore selected plot index
    if (_plots.isNotEmpty) {
      final index = plotSettings.selectedPlotIndex;
      if (index >= 0 && index < _plots.length) {
        _selectedPlotId = _plots[index].id;
      } else {
        _selectedPlotId = _plots.first.id;
      }
    } else {
      _selectedPlotId = null;
    }
  }

  void _initializeController() {
    // Removed forced default plot creation to allow empty state persistence
    // if (_plots.isEmpty) {
    //   _addDefaultPlot(save: false);
    // }

    _itemController = DashboardItemController.withDelegate(
      itemStorageDelegate: _PlotGridStorageDelegate(
        plots: _plots,
        onItemsUpdatedCallback: _updateLayoutFromDelegate,
        onItemsAddedCallback: (items) {
          // Handle items added via controller if needed
        },
        onItemsDeletedCallback: (items) {
          // Handle items deleted via controller if needed
        },
      ),
    );
  }

  void _addDefaultPlot({bool save = true}) {
    final newId = 'plot_${DateTime.now().millisecondsSinceEpoch}';

    // Get current time window from settings
    final timeWindowLabel = widget.settingsManager.plots.timeWindow;
    final timeWindowOption = TimeWindowOption.availableWindows.firstWhere(
      (w) => w.label == timeWindowLabel,
      orElse: () => TimeWindowOption.getDefault(),
    );

    final newPlot = PlotConfiguration(
      id: newId,
      timeWindow: timeWindowOption.duration,
      layoutData: const PlotLayoutData(x: 0, y: 0, width: 8, height: 6),
    );

    _plots.add(newPlot);
    if (save) {
      _saveToSettings();
      _itemController.add(
        DashboardItem(
          width: newPlot.layoutData.width,
          height: newPlot.layoutData.height,
          identifier: newPlot.id,
          startX: newPlot.layoutData.x,
          startY: newPlot.layoutData.y,
        ),
      );
    }
  }

  void _saveToSettings() {
    final selectedIndex = _selectedPlotId != null
        ? _plots.indexWhere((plot) => plot.id == _selectedPlotId)
        : 0;

    // Handle empty list safely for clamp
    final safeIndex = _plots.isEmpty
        ? 0
        : selectedIndex.clamp(0, _plots.length - 1);

    widget.settingsManager.updatePlots(
      widget.settingsManager.plots.copyWith(
        configurations: _plots,
        selectedPlotIndex: safeIndex,
        propertiesPanelVisible: _showPropertiesPanel,
      ),
    );
  }

  void _updateLayoutFromDelegate(List<DashboardItem> items) {
    setState(() {
      for (final item in items) {
        final index = _plots.indexWhere((p) => p.id == item.identifier);
        if (index != -1) {
          _plots[index] = _plots[index].copyWith(
            layoutData: PlotLayoutData(
              x: item.layoutData.startX,
              y: item.layoutData.startY,
              width: item.layoutData.width,
              height: item.layoutData.height,
            ),
          );
        }
      }
    });
    _saveToSettings();
  }

  void _selectPlot(String plotId) {
    setState(() {
      _selectedPlotId = plotId;
    });
    _saveToSettings();
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
                          : Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.2),
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
      _itemController.delete(plotId);
    });
    _saveToSettings();
  }

  int _getPlotIndex(String plotId) {
    return _plots.indexWhere((p) => p.id == plotId);
  }

  // --- Public Methods for RealtimeDataDisplay ---

  void addNewPlot() {
    _addDefaultPlot(save: true);
  }

  void clearAllPlots() {
    setState(() {
      _plots.clear();
      _selectedPlotId = null;
      _itemController.clear();
    });
    _saveToSettings();
  }

  void setEditMode(bool enabled) {
    _itemController.isEditing = enabled;
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

        // Check if signal already exists
        final existingSignalIndex = plot.yAxis.signals.indexWhere(
          (s) => s.fieldKey == fieldKey,
        );

        List<PlotSignalConfiguration> updatedSignals;
        if (existingSignalIndex != -1) {
          // Remove if exists (toggle)
          updatedSignals = List.from(plot.yAxis.signals)
            ..removeAt(existingSignalIndex);
        } else {
          // Add new signal
          updatedSignals = List.from(plot.yAxis.signals)
            ..add(
              PlotSignalConfiguration(
                id: fieldKey,
                messageType: messageType,
                fieldName: fieldName,
                displayName: fieldName,
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
      // No plot selected and no plots exist, create one
      addNewPlot();
      // Then assign (recursive call)
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

  // --- Panel Builders ---

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
      onAddSignals: () {
        // TODO: Show color picker or handle add signal
      },
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
          child: Dashboard(
            dashboardItemController: _itemController,
            slotCount: 24,
            editModeSettings: EditModeSettings(
              paintBackgroundLines: false,
              fillEditingBackground: false,
              resizeCursorSide: 15,
              curve: Curves.easeOut,
              duration: const Duration(milliseconds: 300),
            ),
            itemBuilder: (DashboardItem item) {
              // Find the plot config.
              final plot = _plots.firstWhere(
                (p) => p.id == item.identifier,
                orElse: () => _plots.first, // Fallback
              );

              final isSelected = _selectedPlotId == plot.id;

              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.2),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header / Drag Handle
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1)
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(7),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Draggable area with move cursor
                          Expanded(
                            child: MouseRegion(
                              cursor: SystemMouseCursors.move,
                              child: Row(
                                children: [
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.drag_indicator,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _selectPlot(plot.id),
                                      child: Text(
                                        plot.yAxis.hasData
                                            ? plot.yAxis.displayName
                                            : 'Plot ${_getPlotIndex(plot.id) + 1}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Close Button - now clickable with default cursor!
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _removePlot(plot.id),
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
                    // Plot Area - force basic cursor to override dashboard's move cursor
                    Expanded(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.basic,
                        child: InteractivePlot(
                          configuration: plot,
                          settingsManager: widget.settingsManager,
                          isAxisSelected: isSelected,
                          onAxisTap: () => _selectPlot(plot.id),
                          onClearAxis: () => _clearPlotAxis(plot.id),
                          onLegendTap: () {
                            if (plot.yAxis.signals.isNotEmpty) {
                              if (plot.yAxis.signals.length == 1) {
                                _handleLegendTap(
                                  plot.id,
                                  plot.yAxis.signals.first,
                                );
                              } else {
                                // Show a simple dialog to pick a signal
                                showDialog(
                                  context: context,
                                  builder: (context) => SimpleDialog(
                                    title: const Text(
                                      'Select Signal to Edit Color',
                                    ),
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
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PlotGridStorageDelegate
    extends DashboardItemStorageDelegate<DashboardItem> {
  final List<PlotConfiguration> plots;
  final Function(List<DashboardItem>) onItemsUpdatedCallback;
  final Function(List<DashboardItem>) onItemsAddedCallback;
  final Function(List<DashboardItem>) onItemsDeletedCallback;

  _PlotGridStorageDelegate({
    required this.plots,
    required this.onItemsUpdatedCallback,
    required this.onItemsAddedCallback,
    required this.onItemsDeletedCallback,
  });

  @override
  bool get cacheItems => true;

  @override
  bool get layoutsBySlotCount => false;

  @override
  FutureOr<List<DashboardItem>> getAllItems(int slotCount) {
    return plots.map((plot) {
      return DashboardItem(
        width: plot.layoutData.width,
        height: plot.layoutData.height,
        identifier: plot.id,
        startX: plot.layoutData.x,
        startY: plot.layoutData.y,
      );
    }).toList();
  }

  @override
  FutureOr<void> onItemsUpdated(List<DashboardItem> items, int slotCount) {
    onItemsUpdatedCallback(items);
  }

  @override
  FutureOr<void> onItemsAdded(List<DashboardItem> items, int slotCount) {
    onItemsAddedCallback(items);
  }

  @override
  FutureOr<void> onItemsDeleted(List<DashboardItem> items, int slotCount) {
    onItemsDeletedCallback(items);
  }
}
