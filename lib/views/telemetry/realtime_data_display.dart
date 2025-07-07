import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/timeseries_data_manager.dart';
import '../../services/settings_manager.dart';
import 'mavlink_message_monitor.dart';
import 'plot_grid.dart';
import '../settings/settings_dialog.dart';

class RealtimeDataDisplay extends StatefulWidget {
  const RealtimeDataDisplay({
    super.key, 
    required this.settingsManager,
    this.autoStartMonitor = true,
  });

  final SettingsManager settingsManager;
  final bool autoStartMonitor;

  @override
  State<RealtimeDataDisplay> createState() => _RealtimeDataDisplayState();
}

class _RealtimeDataDisplayState extends State<RealtimeDataDisplay> {
  final TimeSeriesDataManager _dataManager = TimeSeriesDataManager();
  final GlobalKey<PlotGridManagerState> _plotGridKey = GlobalKey<PlotGridManagerState>();
  
  // Current telemetry data (kept for message tracking functionality)  
  late bool _isPaused;
  StreamSubscription? _dataStreamSubscription;

  @override
  void initState() {
    super.initState();
    
    // Initialize from settings
    _isPaused = widget.settingsManager.connection.isPaused;
    
    // Listen for settings changes
    widget.settingsManager.addListener(_onSettingsChanged);
    
    // Listen for data changes to update connection status
    _dataStreamSubscription = _dataManager.dataStream.listen((_) {
      if (mounted) {
        setState(() {}); // Trigger rebuild to update connection status
      }
    });
    
    // Sync data manager with current pause state
    if (_isPaused) {
      _dataManager.pause();
    } else {
      _dataManager.resume();
    }
  }
  
  void _onSettingsChanged() {
    // Only handle pause state changes - connection management is in MainNavigation
    final newIsPaused = widget.settingsManager.connection.isPaused;
    
    if (newIsPaused != _isPaused) {
      // Pause state changed
      setState(() {
        _isPaused = newIsPaused;
        if (_isPaused) {
          _dataManager.pause();
        } else {
          _dataManager.resume();
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
    _plotGridKey.currentState?.assignFieldToSelectedPlot(messageType, fieldName);
  }

  
  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _dataManager.pause();
      } else {
        _dataManager.resume();
      }
    });
    
    // Save pause state to settings
    widget.settingsManager.updatePauseState(_isPaused);
  }
  
  void _clearAllPlots() {
    _plotGridKey.currentState?.clearAllPlots();
    _dataManager.clearAllData();
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
        settingsManager: widget.settingsManager,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Floating action buttons in top-right corner
          SizedBox(
            width: double.infinity,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                      onPressed: _togglePause,
                      tooltip: _isPaused ? 'PAUSED (click to resume)' : 'PLAYING (click to pause & enable zoom/hover)',
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear_all),
                      onPressed: _clearAllPlots,
                      tooltip: 'Clear All Plots',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: _openSettings,
                      tooltip: 'Settings',
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildConnectionStatus(),
          Expanded(
            child: Row(
              children: [
                MavlinkMessageMonitor(
                  autoStart: widget.autoStartMonitor,
                  onFieldSelected: _onFieldSelected,
                  plottedFields: _plotGridKey.currentState?.allPlottedFields ?? {},
                  selectedPlotFields: _plotGridKey.currentState?.selectedPlotFields ?? {},
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
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

  Widget _buildConnectionStatus() {
    // Determine connection status based on recent data availability and pause state
    final hasRecentData = _hasRecentData();
    final isConnected = hasRecentData && !_isPaused;
    
    final connection = widget.settingsManager.connection;
    final statusColor = _isPaused ? Colors.orange : (isConnected ? Colors.green : Colors.red);
    
    String statusText;
    if (_isPaused) {
      statusText = 'Paused';
    } else if (connection.enableSpoofing) {
      statusText = isConnected ? 'Spoof mode connected' : 'Spoof mode disconnected';
    } else {
      statusText = isConnected ? 'Connected' : 'Disconnected';
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.circle, color: statusColor, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                statusText,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Check if there's been recent data activity (within last 5 seconds)
  bool _hasRecentData() {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(seconds: 5));
    
    // Check each available field for recent data points
    for (final fieldKey in _dataManager.getAvailableFields()) {
      final parts = fieldKey.split('.');
      if (parts.length >= 2) {
        final messageType = parts[0];
        final fieldName = parts.sublist(1).join('.');
        final data = _dataManager.getFieldData(messageType, fieldName);
        
        // Check if any data point is recent
        if (data.any((point) => point.timestamp.isAfter(cutoff))) {
          return true;
        }
      }
    }
    
    return false;
  }
}