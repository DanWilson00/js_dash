import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:dart_mavlink/dialects/common.dart';
import '../../services/settings_manager.dart';
import '../../services/usb_serial_spoof_service.dart';
import '../../services/bing_maps_service.dart';

class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.settingsManager,
  });

  final SettingsManager settingsManager;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final MapController _mapController = MapController();
  final UsbSerialSpoofService _mavlinkService = UsbSerialSpoofService();
  
  // Default center coordinates (Los Angeles area - matches spoofer starting point)
  static const LatLng _defaultCenter = LatLng(34.0522, -118.2437);
  
  // Map layers
  BingMapType _currentLayer = BingMapType.aerial;
  
  // Vehicle location (updated by MAVLink data)
  LatLng? _vehicleLocation;
  double? _vehicleHeading;
  
  // Vehicle following control
  bool _isFollowingVehicle = true;
  
  // Path tracking
  final List<LatLng> _vehiclePath = [];
  bool _showPath = true;
  int _maxPathPoints = 200; // Configurable path length (number of points)
  
  // Subscriptions for MAVLink data
  StreamSubscription<GlobalPositionInt>? _gpsSubscription;
  StreamSubscription<VfrHud>? _hudSubscription;

  @override
  void initState() {
    super.initState();
    _initializeSpoofer();
    _initializeMavlinkListeners();
  }
  
  void _initializeSpoofer() async {
    await _mavlinkService.initialize();
    await _mavlinkService.startSpoofing();
  }
  
  // Calculate distance between two points in meters
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double radiusOfEarth = 6371000; // Earth's radius in meters
    
    final double lat1Rad = point1.latitude * (math.pi / 180);
    final double lat2Rad = point2.latitude * (math.pi / 180);
    final double deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180);
    final double deltaLonRad = (point2.longitude - point1.longitude) * (math.pi / 180);
    
    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLonRad / 2) * math.sin(deltaLonRad / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return radiusOfEarth * c;
  }
  
  void _initializeMavlinkListeners() {
    // Listen to GPS position updates
    _gpsSubscription = _mavlinkService.gpsStream.listen((gps) {
      final newLocation = LatLng(
        gps.lat / 1e7, // Convert from 1E7 degrees to decimal degrees
        gps.lon / 1e7,
      );
      
      setState(() {
        _vehicleLocation = newLocation;
        
        // Add to path if location has changed significantly (avoid duplicate points)
        if (_vehiclePath.isEmpty || 
            _calculateDistance(_vehiclePath.last, newLocation) > 0.5) { // 0.5 meter threshold
          _vehiclePath.add(newLocation);
          
          // Maintain maximum path length
          if (_vehiclePath.length > _maxPathPoints) {
            _vehiclePath.removeAt(0); // Remove oldest point
          }
        }
      });
      
      // Automatically center map on vehicle location if following is enabled
      if (_isFollowingVehicle) {
        _mapController.move(newLocation, _mapController.camera.zoom);
      }
    });
    
    // Listen to VFR HUD for heading updates
    _hudSubscription = _mavlinkService.vfrHudStream.listen((hud) {
      setState(() {
        _vehicleHeading = hud.heading.toDouble();
      });
    });
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _hudSubscription?.cancel();
    _mavlinkService.stopSpoofing();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _vehicleLocation ?? _defaultCenter,
              initialZoom: 15.0,
              minZoom: 5.0,
              maxZoom: 18.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onMapEvent: (MapEvent mapEvent) {
                // Disable following when user manually pans the map
                if (mapEvent is MapEventMoveStart && 
                    mapEvent.source == MapEventSource.onDrag) {
                  if (_isFollowingVehicle) {
                    setState(() {
                      _isFollowingVehicle = false;
                    });
                  }
                }
              },
            ),
            children: [
              // Tile layer (OpenStreetMap)
              TileLayer(
                urlTemplate: _getTileUrl(),
                userAgentPackageName: 'com.example.js_dash',
              ),
              
              // Vehicle path layer
              if (_showPath && _vehiclePath.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _vehiclePath,
                      color: Colors.red,
                      strokeWidth: 3.0,
                    ),
                  ],
                ),
              
              // Vehicle marker layer
              if (_vehicleLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _vehicleLocation!,
                      width: 40.0,
                      height: 40.0,
                      child: _buildVehicleMarker(),
                    ),
                  ],
                ),
            ],
          ),
          
          // Map controls overlay
          _buildMapControls(),
        ],
      ),
    );
  }

  String _getTileUrl() {
    switch (_currentLayer) {
      case BingMapType.aerial:
        // ESRI World Imagery (free satellite imagery)
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case BingMapType.aerialWithLabels:
        // ESRI World Imagery with reference overlay
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case BingMapType.road:
        // OpenStreetMap for roads
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      default:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
  }

  Widget _buildVehicleMarker() {
    return Transform.rotate(
      angle: _vehicleHeading != null ? _vehicleHeading! * (3.14159 / 180) : 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(
          Icons.navigation,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildMapControls() {
    return Positioned(
      top: 20,
      right: 20,
      child: Column(
        children: [
          // Layer selector
          Container(
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLayerButton('Satellite', BingMapType.aerial),
                _buildLayerButton('Hybrid', BingMapType.aerialWithLabels),
                _buildLayerButton('Road', BingMapType.road),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Zoom controls
          Container(
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    final currentCenter = _mapController.camera.center;
                    _mapController.move(
                      currentCenter,
                      currentZoom + 1,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.remove, color: Colors.white),
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    final currentCenter = _mapController.camera.center;
                    _mapController.move(
                      currentCenter,
                      currentZoom - 1,
                    );
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Path controls
          Container(
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toggle path visibility
                IconButton(
                  icon: Icon(
                    _showPath ? Icons.timeline : Icons.timeline_outlined,
                    color: _showPath ? Colors.blue : Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _showPath = !_showPath;
                    });
                  },
                  tooltip: _showPath ? 'Hide Path' : 'Show Path',
                ),
                // Clear path button
                if (_vehiclePath.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_all, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _vehiclePath.clear();
                      });
                    },
                    tooltip: 'Clear Path',
                  ),
                // Path length configuration
                GestureDetector(
                  onTap: _showPathConfigDialog,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text(
                      '${_vehiclePath.length}/$_maxPathPoints',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Vehicle following controls
          if (_vehicleLocation != null)
            Container(
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Follow vehicle toggle
                  IconButton(
                    icon: Icon(
                      _isFollowingVehicle ? Icons.gps_fixed : Icons.gps_not_fixed,
                      color: _isFollowingVehicle ? Colors.green : Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _isFollowingVehicle = !_isFollowingVehicle;
                        // If enabling follow mode, immediately center on vehicle
                        if (_isFollowingVehicle && _vehicleLocation != null) {
                          _mapController.move(_vehicleLocation!, _mapController.camera.zoom);
                        }
                      });
                    },
                    tooltip: _isFollowingVehicle ? 'Stop Following Vehicle' : 'Follow Vehicle',
                  ),
                  // Manual center on vehicle button
                  IconButton(
                    icon: const Icon(Icons.my_location, color: Colors.white),
                    onPressed: () {
                      if (_vehicleLocation != null) {
                        _mapController.move(_vehicleLocation!, _mapController.camera.zoom);
                      }
                    },
                    tooltip: 'Center on Vehicle',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLayerButton(String label, BingMapType layerType) {
    final bool isSelected = _currentLayer == layerType;
    return SizedBox(
      width: 80,
      child: TextButton(
        onPressed: () {
          setState(() {
            _currentLayer = layerType;
          });
        },
        style: TextButton.styleFrom(
          backgroundColor: isSelected ? Colors.blue : Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  // Method to update vehicle location (will be called by MAVLink data)
  void updateVehicleLocation(LatLng location, double? heading) {
    setState(() {
      _vehicleLocation = location;
      _vehicleHeading = heading;
    });
  }
  
  // Show path configuration dialog
  void _showPathConfigDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        int tempMaxPathPoints = _maxPathPoints;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Path Configuration'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Maximum path points: $tempMaxPathPoints'),
                  const SizedBox(height: 16),
                  Slider(
                    value: tempMaxPathPoints.toDouble(),
                    min: 50,
                    max: 1000,
                    divisions: 19,
                    label: tempMaxPathPoints.toString(),
                    onChanged: (value) {
                      setDialogState(() {
                        tempMaxPathPoints = value.round();
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fewer points = shorter path\nMore points = longer path',
                    style: TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _maxPathPoints = tempMaxPathPoints;
                      // Trim existing path if it's too long
                      while (_vehiclePath.length > _maxPathPoints) {
                        _vehiclePath.removeAt(0);
                      }
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}