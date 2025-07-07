import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/mavlink_service.dart';
import '../../services/mavlink_spoof_service.dart';
import '../../services/usb_serial_spoof_service.dart';
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
  final MavlinkService _mavlinkService = MavlinkService();
  final MavlinkSpoofService _spoofService = MavlinkSpoofService();
  final UsbSerialSpoofService _usbSerialSpoofService = UsbSerialSpoofService();
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
    _isUsingSpoof = widget.settingsManager.connection.enableSpoofing;
    _isPaused = widget.settingsManager.connection.isPaused;
    
    // Listen for settings changes
    widget.settingsManager.addListener(_onSettingsChanged);
    
    // Sync data manager with initial pause state
    if (_isPaused) {
      _dataManager.pause();
    } else {
      _dataManager.resume();
    }
    
    _initializeServicesOnce();
  }
  
  Future<void> _initializeServicesOnce() async {
    // Initialize services once only
    await _mavlinkService.initialize();
    await _usbSerialSpoofService.initialize();
    _dataManager.startTracking(widget.settingsManager);
    
    _startDataSource();
  }
  
  Future<void> _startDataSource() async {
    if (_isUsingSpoof) {
      _startSpoofMode();
    } else {
      await _connectRealMAVLink();
    }
  }
  
  void _onSettingsChanged() {
    // Check if connection mode or pause state changed
    final newUseSpoofMode = widget.settingsManager.connection.enableSpoofing;
    final newIsPaused = widget.settingsManager.connection.isPaused;
    
    if (newUseSpoofMode != _isUsingSpoof) {
      // Connection mode changed, restart data source
      _cleanup();
      setState(() {
        _isUsingSpoof = newUseSpoofMode;
        _isConnected = false;
        _lastPacketTime = null;
      });
      _startDataSource(); // Note: This is async but we don't await it
    }
    
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
    _updateTimer?.cancel();
    widget.settingsManager.removeListener(_onSettingsChanged);
    _cleanup();
    super.dispose();
  }

  void _startSpoofMode() {
    final connection = widget.settingsManager.connection;
    
    if (connection.spoofMode == 'usb_serial') {
      // Use USB Serial Spoof Service
      _subscriptions.addAll([
        _usbSerialSpoofService.heartbeatStream.listen((_) {
          _lastPacketTime = DateTime.now();
          _isConnected = true;
          _scheduleUpdate();
        }),
        _usbSerialSpoofService.sysStatusStream.listen((_) {
          _lastPacketTime = DateTime.now();
          _scheduleUpdate();
        }),
        _usbSerialSpoofService.attitudeStream.listen((_) {
          _lastPacketTime = DateTime.now();
          _scheduleUpdate();
        }),
        _usbSerialSpoofService.gpsStream.listen((_) {
          _lastPacketTime = DateTime.now();
          _scheduleUpdate();
        }),
        _usbSerialSpoofService.vfrHudStream.listen((_) {
          _lastPacketTime = DateTime.now();
          _scheduleUpdate();
        }),
      ]);
      
      _usbSerialSpoofService.startSpoofing(
        baudRate: connection.spoofBaudRate,
        systemId: connection.spoofSystemId,
        componentId: connection.spoofComponentId,
      );
    } else {
      // Use Timer-based Spoof Service (default)
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
    }
    
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
      
      final connection = widget.settingsManager.connection;
      if (connection.connectionType == 'udp') {
        await _mavlinkService.connectUDP(
          host: connection.mavlinkHost,
          port: connection.mavlinkPort,
        );
      } else if (connection.connectionType == 'serial') {
        await _mavlinkService.connectSerial(
          portName: connection.serialPort,
          baudRate: connection.serialBaudRate,
        );
      }
      
      setState(() => _isConnected = _mavlinkService.isConnected);
    } catch (e) {
      setState(() => _isConnected = false);
    }
  }

  void _cleanup() {
    // Cancel all stream subscriptions
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    
    // Stop both spoof services
    _spoofService.stopSpoofing();
    _usbSerialSpoofService.stopSpoofing();
    
    // Also disconnect MAVLink service if connected
    _mavlinkService.disconnect();
    
    // Don't stop tracking - we want to keep the data manager running
    // _dataManager.stopTracking();
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
    final statusColor = _isPaused ? Colors.orange : (_isConnected ? Colors.green : Colors.red);
    final statusText = _isPaused ? 'Paused' : (_isConnected ? 'Connected' : 'Disconnected');
    
    String modeText;
    final connection = widget.settingsManager.connection;
    if (connection.enableSpoofing) {
      switch (connection.spoofMode) {
        case 'timer':
          modeText = 'SPOOF MODE (Timer)';
          break;
        case 'usb_serial':
          modeText = 'SPOOF MODE (USB Serial)';
          break;
        default:
          modeText = 'SPOOF MODE';
      }
    } else {
      switch (connection.connectionType) {
        case 'udp':
          modeText = 'UDP MAVLINK';
          break;
        case 'serial':
          modeText = 'SERIAL MAVLINK';
          break;
        default:
          modeText = 'MAVLINK';
      }
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