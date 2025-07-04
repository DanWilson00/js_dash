import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/mavlink_service.dart';
import '../../services/mavlink_spoof_service.dart';
import '../../services/timeseries_data_manager.dart';
import '../../services/settings_manager.dart';
import 'mavlink_message_monitor.dart';
import 'plot_grid.dart';

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
  final MavlinkService _mavlinkService = MavlinkService();
  final MavlinkSpoofService _spoofService = MavlinkSpoofService();
  final TimeSeriesDataManager _dataManager = TimeSeriesDataManager();
  
  final List<StreamSubscription> _subscriptions = [];
  final GlobalKey<PlotGridManagerState> _plotGridKey = GlobalKey<PlotGridManagerState>();
  
  // Current telemetry data (kept for message tracking functionality)
  
  late bool _isUsingSpoof;
  bool _isConnected = false;
  DateTime? _lastPacketTime;
  late bool _isPaused;
  
  // Update throttling
  Timer? _updateTimer;
  bool _pendingUpdate = false;
  static const _uiUpdateInterval = Duration(milliseconds: 100); // 10 FPS for UI updates, synced with plots

  @override
  void initState() {
    super.initState();
    
    // Initialize from settings
    _isUsingSpoof = widget.settingsManager.connection.useSpoofMode;
    _isPaused = widget.settingsManager.connection.isPaused;
    
    _initializeServices();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _cleanup();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    await _mavlinkService.initialize();
    _dataManager.startTracking();
    
    if (_isUsingSpoof) {
      _startSpoofMode();
    } else {
      await _connectRealMAVLink();
    }
  }

  void _startSpoofMode() {
    _subscriptions.addAll([
      _spoofService.heartbeatStream.listen((_) {
        _lastPacketTime = DateTime.now();
        _isConnected = true;
        _scheduleUpdate();
      }),
      _spoofService.sysStatusStream.listen((_) {
        _lastPacketTime = DateTime.now();
        _scheduleUpdate();
      }),
      _spoofService.attitudeStream.listen((_) {
        _lastPacketTime = DateTime.now();
        _scheduleUpdate();
      }),
      _spoofService.gpsStream.listen((_) {
        _lastPacketTime = DateTime.now();
        _scheduleUpdate();
      }),
      _spoofService.vfrHudStream.listen((_) {
        _lastPacketTime = DateTime.now();
        _scheduleUpdate();
      }),
    ]);
    
    _spoofService.startSpoofing();
    setState(() => _isConnected = true);
  }

  Future<void> _connectRealMAVLink() async {
    try {
      _subscriptions.addAll([
        _mavlinkService.heartbeatStream.listen((_) {
          _lastPacketTime = DateTime.now();
          _isConnected = true;
          _scheduleUpdate();
        }),
        _mavlinkService.sysStatusStream.listen((_) {
          _lastPacketTime = DateTime.now();
          _scheduleUpdate();
        }),
        _mavlinkService.attitudeStream.listen((_) {
          _lastPacketTime = DateTime.now();
          _scheduleUpdate();
        }),
        _mavlinkService.gpsStream.listen((_) {
          _lastPacketTime = DateTime.now();
          _scheduleUpdate();
        }),
        _mavlinkService.vfrHudStream.listen((_) {
          _lastPacketTime = DateTime.now();
          _scheduleUpdate();
        }),
      ]);
      
      await _mavlinkService.connectUDP();
      setState(() => _isConnected = _mavlinkService.isConnected);
    } catch (e) {
      setState(() => _isConnected = false);
    }
  }

  void _cleanup() {
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _spoofService.stopSpoofing();
    _dataManager.stopTracking();
  }

  void _scheduleUpdate() {
    _pendingUpdate = true;
    
    // If no timer is active, start one
    if (_updateTimer == null || !_updateTimer!.isActive) {
      _updateTimer = Timer(_uiUpdateInterval, () {
        if (mounted && _pendingUpdate) {
          _pendingUpdate = false;
          setState(() {});
        }
      });
    }
  }
  
  void _onFieldSelected(String messageType, String fieldName) {
    // Assign the selected field to the currently selected plot
    _plotGridKey.currentState?.assignFieldToSelectedPlot(messageType, fieldName);
  }

  void _toggleMode() {
    _cleanup();
    setState(() {
      _isUsingSpoof = !_isUsingSpoof;
      _isConnected = false;
      _lastPacketTime = null;
    });
    
    // Save connection mode to settings
    widget.settingsManager.updateConnectionMode(_isUsingSpoof);
    
    _initializeServices();
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
                      tooltip: _isPaused ? 'Resume Streaming' : 'Pause Streaming (enables zoom & hover)',
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear_all),
                      onPressed: _clearAllPlots,
                      tooltip: 'Clear All Plots',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(_isUsingSpoof ? Icons.bug_report : Icons.wifi),
                      onPressed: _toggleMode,
                      tooltip: _isUsingSpoof ? 'Switch to Real MAVLink' : 'Switch to Spoof Mode',
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
    final statusColor = _isPaused ? Colors.orange : (_isConnected ? Colors.green : Colors.red);
    final statusText = _isPaused ? 'Paused' : (_isConnected ? 'Connected' : 'Disconnected');
    final modeText = _isUsingSpoof ? 'SPOOF MODE' : 'REAL MAVLINK';
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.circle, color: statusColor, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '$statusText ($modeText)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            if (_lastPacketTime != null)
              Flexible(
                child: Text(
                  _formatTime(_lastPacketTime!),
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }


  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time).inSeconds;
    if (diff == 0) return '';
    return '${diff}s ago';
  }
}