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
  final GlobalKey<PlotGridManagerState> _plotGridKey =
      GlobalKey<PlotGridManagerState>();

  // Current telemetry data (kept for message tracking functionality)
  late bool _isPaused;
  StreamSubscription? _dataStreamSubscription;
  double _messagePanelWidth = 350.0;

  @override
  void initState() {
    super.initState();

    // Initialize from settings
    _isPaused = widget.settingsManager.connection.isPaused;

    // Listen for settings changes
    widget.settingsManager.addListener(_onSettingsChanged);

    // Listen for data changes to update connection status via TelemetryRepository
    // This will be set up in didChangeDependencies when ref is available
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
    // Only handle pause state changes - connection management is in MainNavigation
    final newIsPaused = widget.settingsManager.connection.isPaused;

    if (newIsPaused != _isPaused) {
      // Pause state changed
      setState(() {
        _isPaused = newIsPaused;
        final repository = ref.read(telemetryRepositoryProvider);
        if (_isPaused) {
          repository.pause();
        } else {
          repository.resume();
        }
      });
    }
  }

  @override
  void dispose() {
    widget.settingsManager.removeListener(_onSettingsChanged);
    _dataStreamSubscription?.cancel();
    super.dispose();
  }

  void _onFieldSelected(String messageType, String fieldName) {
    // Assign the selected field to the currently selected plot
    _plotGridKey.currentState?.assignFieldToSelectedPlot(
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

  void _clearAllPlots() {
    _plotGridKey.currentState?.clearAllPlots();
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

  @override
  Widget build(BuildContext context) {
    final uiScale = widget.settingsManager.appearance.uiScale;

    return Scaffold(
      body: Column(
        children: [
          // Floating action buttons in top-right corner
          SizedBox(
            width: double.infinity,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(8.0 * uiScale),
                child: Row(
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
                        value:
                            TimeWindowOption.getDefault(), // TODO: Sync with actual state
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
                            _plotGridKey.currentState?.updateTimeWindow(window);
                            // Force rebuild to update dropdown value if we were tracking it here
                            // For now, we just send it to the grid
                            setState(() {});
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
                      onPressed: () => _plotGridKey.currentState?.addNewPlot(),
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
              ),
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
                        _plotGridKey.currentState?.allPlottedFields ?? {},
                    selectedPlotFields:
                        _plotGridKey.currentState?.selectedPlotFields ?? {},
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
                    child: PlotGridManager(
                      key: _plotGridKey,
                      settingsManager: widget.settingsManager,
                      onFieldAssignment: () {
                        // Force refresh to update field highlighting
                        setState(() {});
                      },
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
