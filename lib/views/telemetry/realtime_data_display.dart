import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/service_providers.dart';
import '../../services/settings_manager.dart';
import '../../models/plot_configuration.dart';
import 'mavlink_message_monitor.dart';
import 'plot_grid.dart';
import '../settings/settings_dialog.dart';

class RealtimeDataDisplay extends ConsumerStatefulWidget {
  const RealtimeDataDisplay({
    super.key,
    required this.settingsManager,
    this.autoStartMonitor = true,
  });

  final SettingsManager settingsManager;
  final bool autoStartMonitor;

  @override
  ConsumerState<RealtimeDataDisplay> createState() =>
      _RealtimeDataDisplayState();
}

class _RealtimeDataDisplayState extends ConsumerState<RealtimeDataDisplay> {
  // Map to store GlobalKeys for each tab ID
  final Map<String, GlobalKey<PlotGridManagerState>> _tabKeys = {};

  GlobalKey<PlotGridManagerState> get _currentPlotGridKey {
    final selectedId = widget.settingsManager.plots.selectedTabId;
    if (!_tabKeys.containsKey(selectedId)) {
      _tabKeys[selectedId] = GlobalKey<PlotGridManagerState>();
    }
    return _tabKeys[selectedId]!;
  }

  // Current telemetry data (kept for message tracking functionality)
  late bool _isPaused;
  late String _currentTimeWindow;
  StreamSubscription? _dataStreamSubscription;
  late double _messagePanelWidth;
  bool _isEditMode = false;
  Timer? _panelWidthSaveTimer;

  // Inline editing state
  String? _editingTabId;
  late TextEditingController _renameController;
  late FocusNode _renameFocusNode;

  @override
  void initState() {
    super.initState();

    _renameController = TextEditingController();
    _renameFocusNode = FocusNode();

    // Initialize from settings
    _isPaused = widget.settingsManager.connection.isPaused;
    _currentTimeWindow = widget.settingsManager.plots.timeWindow;
    _messagePanelWidth = widget.settingsManager.plots.messagePanelWidth;

    // Listen for settings changes
    widget.settingsManager.addListener(_onSettingsChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Set up data stream subscription using TelemetryRepository
    final repository = ref.read(telemetryRepositoryProvider);
    _dataStreamSubscription = repository.dataStream.listen((_) {
      if (mounted) {
        setState(() {}); // Trigger rebuild to update connection status
      }
    });

    // Sync repository with current pause state
    if (_isPaused) {
      repository.pause();
    } else {
      repository.resume();
    }
  }

  void _onSettingsChanged() {
    // Check for pause state changes
    final newIsPaused = widget.settingsManager.connection.isPaused;
    // Check for time window changes
    final newTimeWindow = widget.settingsManager.plots.timeWindow;

    if (newIsPaused != _isPaused || newTimeWindow != _currentTimeWindow) {
      setState(() {
        _isPaused = newIsPaused;
        _currentTimeWindow = newTimeWindow;

        final repository = ref.read(telemetryRepositoryProvider);
        if (_isPaused) {
          repository.pause();
        } else {
          repository.resume();
        }
      });
    }
    // Trigger rebuild for tab changes
    setState(() {});
  }

  @override
  void dispose() {
    _panelWidthSaveTimer?.cancel();
    widget.settingsManager.removeListener(_onSettingsChanged);
    _dataStreamSubscription?.cancel();
    _renameController.dispose();
    _renameFocusNode.dispose();
    super.dispose();
  }

  void _onFieldSelected(String messageType, String fieldName) {
    // Assign the selected field to the currently selected plot
    _currentPlotGridKey.currentState?.assignFieldToSelectedPlot(
      messageType,
      fieldName,
    );
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      final repository = ref.read(telemetryRepositoryProvider);
      if (_isPaused) {
        repository.pause();
      } else {
        repository.resume();
      }
    });

    // Save pause state to settings
    widget.settingsManager.updatePauseState(_isPaused);
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      _currentPlotGridKey.currentState?.setEditMode(_isEditMode);
    });
  }

  void _clearAllPlots() {
    _currentPlotGridKey.currentState?.clearAllPlots();
    final repository = ref.read(telemetryRepositoryProvider);
    repository.clearAllData();
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (context) =>
          SettingsDialog(settingsManager: widget.settingsManager),
    );
  }

  void _addTab() {
    widget.settingsManager.addPlotTab(
      'Tab ${widget.settingsManager.plots.tabs.length + 1}',
    );
  }

  void _removeTab(String tabId) {
    widget.settingsManager.removePlotTab(tabId);
  }

  void _renameTab(String tabId, String newName) {
    widget.settingsManager.renamePlotTab(tabId, newName);
  }

  void _selectTab(String tabId) {
    widget.settingsManager.selectPlotTab(tabId);
  }

  void _startEditing(String tabId, String currentName) {
    setState(() {
      _editingTabId = tabId;
      _renameController.text = currentName;
      // Request focus after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _renameFocusNode.requestFocus();
      });
    });
  }

  void _stopEditing() {
    if (_editingTabId != null) {
      if (_renameController.text.isNotEmpty) {
        _renameTab(_editingTabId!, _renameController.text);
      }
      setState(() {
        _editingTabId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uiScale = widget.settingsManager.appearance.uiScale;
    final tabs = widget.settingsManager.plots.tabs;
    final selectedTabId = widget.settingsManager.plots.selectedTabId;

    // Ensure keys exist for all tabs
    for (var tab in tabs) {
      if (!_tabKeys.containsKey(tab.id)) {
        _tabKeys[tab.id] = GlobalKey<PlotGridManagerState>();
      }
    }

    // Cleanup keys for removed tabs
    _tabKeys.removeWhere((key, _) => !tabs.any((t) => t.id == key));

    // Get current time window from settings
    final currentTimeWindowLabel = widget.settingsManager.plots.timeWindow;
    final currentTimeWindow = TimeWindowOption.availableWindows.firstWhere(
      (w) => w.label == currentTimeWindowLabel,
      orElse: () => TimeWindowOption.getDefault(),
    );

    return Scaffold(
      body: Column(
        children: [
          // Tab bar
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(8.0 * uiScale),
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: Row(
              children: [
                // Tabs on the left
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var tab in tabs)
                          Padding(
                            padding: EdgeInsets.only(right: 4 * uiScale),
                            child: Material(
                              color: tab.id == selectedTabId
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(4),
                              child: InkWell(
                                onTap: () => _selectTab(tab.id),
                                onDoubleTap: () =>
                                    _startEditing(tab.id, tab.name),
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12 * uiScale,
                                    vertical: 6 * uiScale,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_editingTabId == tab.id)
                                        SizedBox(
                                          width: 100 * uiScale,
                                          child: TextField(
                                            controller: _renameController,
                                            focusNode: _renameFocusNode,
                                            style: TextStyle(
                                              fontSize: 14 * uiScale,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              contentPadding: EdgeInsets.zero,
                                              border: InputBorder.none,
                                            ),
                                            onSubmitted: (_) => _stopEditing(),
                                            onTapOutside: (_) => _stopEditing(),
                                          ),
                                        )
                                      else
                                        Text(
                                          tab.name,
                                          style: TextStyle(
                                            fontSize: 14 * uiScale,
                                            fontWeight: tab.id == selectedTabId
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      if (tabs.length > 1 &&
                                          _editingTabId != tab.id) ...[
                                        SizedBox(width: 8 * uiScale),
                                        InkWell(
                                          onTap: () => _removeTab(tab.id),
                                          child: Icon(
                                            Icons.close,
                                            size: 16 * uiScale,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          iconSize: 20 * uiScale,
                          onPressed: _addTab,
                          tooltip: 'Add Tab',
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 16 * uiScale),
                // Controls on the right
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatusIndicator(uiScale),
                    SizedBox(width: 16 * uiScale),
                    // Time Window Selector
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8 * uiScale),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<TimeWindowOption>(
                        value: currentTimeWindow,
                        items: TimeWindowOption.availableWindows
                            .map(
                              (w) => DropdownMenuItem(
                                value: w,
                                child: Text(
                                  w.label,
                                  style: TextStyle(fontSize: 14 * uiScale),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (window) {
                          if (window != null) {
                            // Update global settings
                            widget.settingsManager.updateTimeWindow(
                              window.label,
                            );
                            // Update existing plots
                            _currentPlotGridKey.currentState?.updateTimeWindow(
                              window,
                            );
                          }
                        },
                        underline: const SizedBox(),
                        isDense: true,
                        icon: const Icon(Icons.access_time, size: 16),
                      ),
                    ),
                    SizedBox(width: 8 * uiScale),
                    IconButton(
                      icon: const Icon(Icons.add),
                      iconSize: 24 * uiScale,
                      onPressed: () =>
                          _currentPlotGridKey.currentState?.addNewPlot(),
                      tooltip: 'Add Plot',
                    ),
                    SizedBox(width: 16 * uiScale),
                    IconButton(
                      icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                      iconSize: 24 * uiScale,
                      onPressed: _togglePause,
                      tooltip: _isPaused
                          ? 'PAUSED (click to resume)'
                          : 'PLAYING (click to pause & enable zoom/hover)',
                    ),
                    IconButton(
                      icon: Icon(_isEditMode ? Icons.lock_open : Icons.lock),
                      iconSize: 24 * uiScale,
                      onPressed: _toggleEditMode,
                      tooltip: _isEditMode
                          ? 'EDIT MODE (drag/resize plots)'
                          : 'VIEW MODE (interact with plots)',
                      color: _isEditMode ? Colors.orange : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear_all),
                      iconSize: 24 * uiScale,
                      onPressed: _clearAllPlots,
                      tooltip: 'Clear All Plots',
                    ),
                    SizedBox(width: 8 * uiScale),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      iconSize: 24 * uiScale,
                      onPressed: _openSettings,
                      tooltip: 'Settings',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: _messagePanelWidth,
                  child: MavlinkMessageMonitor(
                    autoStart: widget.autoStartMonitor,
                    onFieldSelected: _onFieldSelected,
                    plottedFields:
                        _currentPlotGridKey.currentState?.allPlottedFields ??
                        {},
                    selectedPlotFields:
                        _currentPlotGridKey.currentState?.selectedPlotFields ??
                        {},
                    uiScale: uiScale,
                  ),
                ),
                // Resizable divider - almost invisible
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _messagePanelWidth =
                            (_messagePanelWidth + details.delta.dx).clamp(
                              250.0,
                              600.0,
                            );
                      });

                      // Debounce saves to avoid excessive writes
                      _panelWidthSaveTimer?.cancel();
                      _panelWidthSaveTimer = Timer(
                        const Duration(milliseconds: 500),
                        () {
                          widget.settingsManager.updateMessagePanelWidth(
                            _messagePanelWidth,
                          );
                        },
                      );
                    },
                    child: Container(
                      width: 8,
                      color: Colors.transparent,
                      child: Center(
                        child: Container(
                          width: 1,
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(8.0 * uiScale),
                    child: IndexedStack(
                      index: tabs
                          .indexWhere((t) => t.id == selectedTabId)
                          .clamp(0, tabs.length - 1),
                      children: [
                        for (var tab in tabs)
                          PlotGridManager(
                            key: _tabKeys[tab.id],
                            settingsManager: widget.settingsManager,
                            tabId: tab.id,
                            onFieldAssignment: () {
                              // Force refresh to update field highlighting
                              setState(() {});
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(double uiScale) {
    // Get actual connection status from connection manager through providers
    final isActuallyConnected = ref.watch(isConnectedProvider);

    final isConnected = isActuallyConnected && !_isPaused;
    final connection = widget.settingsManager.connection;
    final statusColor = _isPaused
        ? Colors.orange
        : (isConnected ? Colors.green : Colors.red);

    String statusText;
    if (_isPaused) {
      statusText = 'Paused';
    } else if (connection.enableSpoofing) {
      statusText = isConnected
          ? 'Spoof mode connected'
          : 'Spoof mode disconnected';
    } else {
      statusText = isConnected ? 'Connected' : 'Disconnected';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: statusColor, size: 12 * uiScale),
        SizedBox(width: 8 * uiScale),
        Text(
          statusText,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: statusColor,
            fontSize: 14 * uiScale,
          ),
        ),
      ],
    );
  }
}
