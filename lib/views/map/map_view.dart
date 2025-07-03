import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:dart_mavlink/dialects/common.dart';
import '../../services/settings_manager.dart';
import '../../services/mavlink_spoof_service.dart';
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
  final MavlinkSpoofService _mavlinkService = MavlinkSpoofService();
  
  // Default center coordinates (San Francisco Bay Area)
  static const LatLng _defaultCenter = LatLng(37.7749, -122.4194);
  
  // Map layers
  BingMapType _currentLayer = BingMapType.aerial;
  
  // Vehicle location (updated by MAVLink data)
  LatLng? _vehicleLocation;
  double? _vehicleHeading;
  
  // Subscriptions for MAVLink data
  StreamSubscription<GlobalPositionInt>? _gpsSubscription;
  StreamSubscription<VfrHud>? _hudSubscription;

  @override
  void initState() {
    super.initState();
    _initializeMavlinkListeners();
  }
  
  void _initializeMavlinkListeners() {
    // Listen to GPS position updates
    _gpsSubscription = _mavlinkService.gpsStream.listen((gps) {
      setState(() {
        _vehicleLocation = LatLng(
          gps.lat / 1e7, // Convert from 1E7 degrees to decimal degrees
          gps.lon / 1e7,
        );
      });
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
            ),
            children: [
              // Tile layer (OpenStreetMap)
              TileLayer(
                urlTemplate: _getTileUrl(),
                userAgentPackageName: 'com.example.js_dash',
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
          
          // Center on vehicle button
          if (_vehicleLocation != null)
            Container(
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: const Icon(Icons.my_location, color: Colors.white),
                onPressed: () {
                  _mapController.move(_vehicleLocation!, 15.0);
                },
                tooltip: 'Center on Vehicle',
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
}