import 'package:flutter/material.dart';
import 'dart:async';
import '../telemetry/realtime_data_display.dart';
import '../dashboard/jetshark_dashboard.dart';
import '../map/map_view.dart';
import '../../services/settings_manager.dart';
import '../../services/mavlink_service.dart';
import '../../services/usb_serial_spoof_service.dart';
import '../../services/timeseries_data_manager.dart';

class MainNavigation extends StatefulWidget {
  final SettingsManager settingsManager;
  final bool autoStartMonitor;
  
  const MainNavigation({
    super.key, 
    required this.settingsManager,
    this.autoStartMonitor = true,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _selectedIndex;
  
  // Centralized data services
  final MavlinkService _mavlinkService = MavlinkService();
  final UsbSerialSpoofService _usbSerialSpoofService = UsbSerialSpoofService();
  final TimeSeriesDataManager _dataManager = TimeSeriesDataManager();
  
  final List<StreamSubscription> _subscriptions = [];
  late bool _isUsingSpoof;
  bool _isConnected = false;
  DateTime? _lastPacketTime;
  late bool _isPaused;

  @override
  void initState() {
    super.initState();
    
    // Restore selected view from settings
    _selectedIndex = widget.settingsManager.navigation.selectedViewIndex;
    
    // Initialize centralized data services
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    // Save selected view to settings
    widget.settingsManager.updateSelectedViewIndex(index);
  }
  
  void _startSpoofMode() {
    final connection = widget.settingsManager.connection;
    
    // Use USB Serial Spoof Service (only option now)
    _subscriptions.addAll([
      _usbSerialSpoofService.heartbeatStream.listen((_) {
        _lastPacketTime = DateTime.now();
        _isConnected = true;
      }),
      _usbSerialSpoofService.sysStatusStream.listen((_) {
        _lastPacketTime = DateTime.now();
      }),
      _usbSerialSpoofService.attitudeStream.listen((_) {
        _lastPacketTime = DateTime.now();
      }),
      _usbSerialSpoofService.gpsStream.listen((_) {
        _lastPacketTime = DateTime.now();
      }),
      _usbSerialSpoofService.vfrHudStream.listen((_) {
        _lastPacketTime = DateTime.now();
      }),
    ]);
    
    _usbSerialSpoofService.startSpoofing(
      baudRate: connection.spoofBaudRate,
      systemId: connection.spoofSystemId,
      componentId: connection.spoofComponentId,
    );
    
    setState(() => _isConnected = true);
  }

  Future<void> _connectRealMAVLink() async {
    try {
      _subscriptions.addAll([
        _mavlinkService.heartbeatStream.listen((_) {
          _lastPacketTime = DateTime.now();
          _isConnected = true;
        }),
        _mavlinkService.sysStatusStream.listen((_) {
          _lastPacketTime = DateTime.now();
        }),
        _mavlinkService.attitudeStream.listen((_) {
          _lastPacketTime = DateTime.now();
        }),
        _mavlinkService.gpsStream.listen((_) {
          _lastPacketTime = DateTime.now();
        }),
        _mavlinkService.vfrHudStream.listen((_) {
          _lastPacketTime = DateTime.now();
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
    
    // Stop spoof service
    _usbSerialSpoofService.stopSpoofing();
    
    // Also disconnect MAVLink service if connected
    _mavlinkService.disconnect();
    
    // Don't stop tracking - we want to keep the data manager running
    // _dataManager.stopTracking();
  }
  
  @override
  void dispose() {
    widget.settingsManager.removeListener(_onSettingsChanged);
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      RealtimeDataDisplay(
        settingsManager: widget.settingsManager,
        autoStartMonitor: widget.autoStartMonitor,
      ),
      MapView(settingsManager: widget.settingsManager),
      const JetsharkDashboard(),
    ];

    return Scaffold(
      body: GestureDetector(
        onTap: () {
          // Allow tapping anywhere on Jetshark dashboard to go back to telemetry
          if (_selectedIndex == 2) {
            _onItemTapped(0);
          }
        },
        child: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: _selectedIndex == 2 ? null : _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: const Color(0xFF00FFFF).withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: const Color(0xFF00FFFF),
        unselectedItemColor: const Color(0xFF666666),
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w300,
          letterSpacing: 1.0,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w300,
          letterSpacing: 1.0,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.timeline),
            label: 'TELEMETRY',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'MAP',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'JETSHARK',
          ),
        ],
      ),
    );
  }
}