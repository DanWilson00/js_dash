import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:dart_mavlink/dialects/common.dart';
import '../services/mavlink_service.dart';
import '../services/mavlink_spoof_service.dart';
import 'mavlink_message_monitor.dart';

class RealtimeDataDisplay extends StatefulWidget {
  const RealtimeDataDisplay({super.key, this.autoStartMonitor = true});

  final bool autoStartMonitor;

  @override
  State<RealtimeDataDisplay> createState() => _RealtimeDataDisplayState();
}

class _RealtimeDataDisplayState extends State<RealtimeDataDisplay> {
  final MavlinkService _mavlinkService = MavlinkService();
  final MavlinkSpoofService _spoofService = MavlinkSpoofService();
  
  final List<StreamSubscription> _subscriptions = [];
  
  // Current telemetry data
  Heartbeat? _lastHeartbeat;
  SysStatus? _lastSysStatus;
  Attitude? _lastAttitude;
  GlobalPositionInt? _lastGPS;
  VfrHud? _lastVfrHud;
  
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
    if (_isUsingSpoof) {
      _startSpoofMode();
    } else {
      await _connectRealMAVLink();
    }
  }

  void _startSpoofMode() {
    _subscriptions.addAll([
      _spoofService.heartbeatStream.listen((heartbeat) {
        setState(() {
          _lastHeartbeat = heartbeat;
          _lastPacketTime = DateTime.now();
          _isConnected = true;
        });
      }),
      _spoofService.sysStatusStream.listen((sysStatus) {
        setState(() {
          _lastSysStatus = sysStatus;
          _lastPacketTime = DateTime.now();
        });
      }),
      _spoofService.attitudeStream.listen((attitude) {
        setState(() {
          _lastAttitude = attitude;
          _lastPacketTime = DateTime.now();
        });
      }),
      _spoofService.gpsStream.listen((gps) {
        setState(() {
          _lastGPS = gps;
          _lastPacketTime = DateTime.now();
        });
      }),
      _spoofService.vfrHudStream.listen((vfrHud) {
        setState(() {
          _lastVfrHud = vfrHud;
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
        _mavlinkService.heartbeatStream.listen((heartbeat) {
          setState(() {
            _lastHeartbeat = heartbeat;
            _lastPacketTime = DateTime.now();
            _isConnected = true;
          });
        }),
        _mavlinkService.sysStatusStream.listen((sysStatus) {
          setState(() {
            _lastSysStatus = sysStatus;
            _lastPacketTime = DateTime.now();
          });
        }),
        _mavlinkService.attitudeStream.listen((attitude) {
          setState(() {
            _lastAttitude = attitude;
            _lastPacketTime = DateTime.now();
          });
        }),
        _mavlinkService.gpsStream.listen((gps) {
          setState(() {
            _lastGPS = gps;
            _lastPacketTime = DateTime.now();
          });
        }),
        _mavlinkService.vfrHudStream.listen((vfrHud) {
          setState(() {
            _lastVfrHud = vfrHud;
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
  }

  void _toggleMode() {
    _cleanup();
    setState(() {
      _isUsingSpoof = !_isUsingSpoof;
      _isConnected = false;
      _lastHeartbeat = null;
      _lastSysStatus = null;
      _lastAttitude = null;
      _lastGPS = null;
      _lastVfrHud = null;
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
      body: Row(
        children: [
          MavlinkMessageMonitor(autoStart: widget.autoStartMonitor),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildConnectionStatus(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isConnected ? _buildTelemetryDisplay() : _buildDisconnectedDisplay(),
                  ),
                ],
              ),
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

  Widget _buildDisconnectedDisplay() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning, size: 64, color: Colors.orange),
          SizedBox(height: 16),
          Text(
            'No MAVLink Connection',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Check your connection settings'),
        ],
      ),
    );
  }

  Widget _buildTelemetryDisplay() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildAttitudeCard(),
        _buildSystemStatusCard(),
        _buildNavigationCard(),
        _buildSpeedCard(),
      ],
    );
  }

  Widget _buildAttitudeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attitude',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_lastAttitude != null) ...[
              _buildDataRow('Roll', '${(_lastAttitude!.roll * 180 / math.pi).toStringAsFixed(1)}°'),
              _buildDataRow('Pitch', '${(_lastAttitude!.pitch * 180 / math.pi).toStringAsFixed(1)}°'),
              _buildDataRow('Yaw', '${(_lastAttitude!.yaw * 180 / math.pi).toStringAsFixed(1)}°'),
            ] else
              const Text('No attitude data'),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_lastSysStatus != null) ...[
              _buildDataRow('Battery', '${(_lastSysStatus!.voltageBattery / 1000).toStringAsFixed(1)}V'),
              _buildDataRow('Battery %', '${_lastSysStatus!.batteryRemaining}%'),
              _buildDataRow('CPU Load', '${(_lastSysStatus!.load / 10).toStringAsFixed(1)}%'),
            ] else
              const Text('No system data'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Navigation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_lastGPS != null) ...[
              _buildDataRow('Lat', '${(_lastGPS!.lat / 1e7).toStringAsFixed(6)}'),
              _buildDataRow('Lon', '${(_lastGPS!.lon / 1e7).toStringAsFixed(6)}'),
              _buildDataRow('Depth', '${(_lastGPS!.alt / 1000).toStringAsFixed(1)}m'),
            ] else
              const Text('No GPS data'),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Speed & Heading',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_lastVfrHud != null) ...[
              _buildDataRow('Speed', '${_lastVfrHud!.groundspeed.toStringAsFixed(1)} m/s'),
              _buildDataRow('Heading', '${_lastVfrHud!.heading}°'),
              _buildDataRow('Throttle', '${_lastVfrHud!.throttle}%'),
            ] else
              const Text('No speed data'),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontFamily: 'monospace')),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time).inSeconds;
    return '${diff}s ago';
  }
}