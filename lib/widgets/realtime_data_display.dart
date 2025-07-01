import 'dart:async';
import 'package:flutter/material.dart';
import '../services/mavlink_service.dart';
import '../services/mavlink_spoof_service.dart';
import '../services/timeseries_data_manager.dart';
import 'mavlink_message_monitor.dart';
import 'plot_grid.dart';

class RealtimeDataDisplay extends StatefulWidget {
  const RealtimeDataDisplay({super.key, this.autoStartMonitor = true});

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
  
  bool _isUsingSpoof = true;
  bool _isConnected = false;
  DateTime? _lastPacketTime;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void dispose() {
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
        setState(() {
          _lastPacketTime = DateTime.now();
          _isConnected = true;
        });
      }),
      _spoofService.sysStatusStream.listen((_) {
        setState(() {
          _lastPacketTime = DateTime.now();
        });
      }),
      _spoofService.attitudeStream.listen((_) {
        setState(() {
          _lastPacketTime = DateTime.now();
        });
      }),
      _spoofService.gpsStream.listen((_) {
        setState(() {
          _lastPacketTime = DateTime.now();
        });
      }),
      _spoofService.vfrHudStream.listen((_) {
        setState(() {
          _lastPacketTime = DateTime.now();
        });
      }),
    ]);
    
    _spoofService.startSpoofing();
    setState(() => _isConnected = true);
  }

  Future<void> _connectRealMAVLink() async {
    try {
      _subscriptions.addAll([
        _mavlinkService.heartbeatStream.listen((_) {
          setState(() {
            _lastPacketTime = DateTime.now();
            _isConnected = true;
          });
        }),
        _mavlinkService.sysStatusStream.listen((_) {
          setState(() {
            _lastPacketTime = DateTime.now();
          });
        }),
        _mavlinkService.attitudeStream.listen((_) {
          setState(() {
            _lastPacketTime = DateTime.now();
          });
        }),
        _mavlinkService.gpsStream.listen((_) {
          setState(() {
            _lastPacketTime = DateTime.now();
          });
        }),
        _mavlinkService.vfrHudStream.listen((_) {
          setState(() {
            _lastPacketTime = DateTime.now();
          });
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
    _initializeServices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submersible Jetski Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_isUsingSpoof ? Icons.bug_report : Icons.wifi),
            onPressed: _toggleMode,
            tooltip: _isUsingSpoof ? 'Switch to Real MAVLink' : 'Switch to Spoof Mode',
          ),
        ],
      ),
      body: Column(
        children: [
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
    final statusColor = _isConnected ? Colors.green : Colors.red;
    final statusText = _isConnected ? 'Connected' : 'Disconnected';
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
                  'Last packet: ${_formatTime(_lastPacketTime!)}',
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
    return '${diff}s ago';
  }
}