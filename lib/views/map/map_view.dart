import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../services/bing_maps_service.dart';
import '../../core/circular_buffer.dart';
import '../../providers/service_providers.dart';
import '../../providers/ui_providers.dart';

class MapView extends ConsumerStatefulWidget {
  const MapView({super.key});

  @override
  ConsumerState<MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<MapView> {
  final MapController _mapController = MapController();

  // Map layers
  BingMapType _currentLayer = BingMapType.aerial;

  // Vehicle location (updated by MAVLink data)
  LatLng? _vehicleLocation;
  double? _vehicleHeading;

  // Path tracking
  final List<LatLng> _vehiclePath = [];

  // Map ready state
  bool _mapReady = false;

  // Track last saved zoom to detect changes
  double? _lastSavedZoom;
  Timer? _saveTimer;

  // Subscription for telemetry data
  StreamSubscription<Map<String, CircularBuffer>>? _dataSubscription;

  @override
  void initState() {
    super.initState();
    _setupTelemetryListening();
    _startPeriodicSave();
  }

  /// Start periodic saving of zoom level when vehicle tracking is enabled
  void _startPeriodicSave() {
    _saveTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_mapReady) {
        final currentZoom = _mapController.camera.zoom;
        if (_lastSavedZoom == null ||
            (currentZoom - _lastSavedZoom!).abs() > 0.1) {
          _lastSavedZoom = currentZoom;
          _saveMapState();
        }
      }
    });
  }

  /// Setup telemetry listening from repository
  void _setupTelemetryListening() {
    final repository = ref.read(telemetryRepositoryProvider);

    // Listen to telemetry data stream from the repository
    _dataSubscription = repository.dataStream.listen((dataBuffers) {
      if (!mounted) return;
      _updateMapFromDataBuffers(dataBuffers);
    });
  }

  /// Update map view from telemetry data buffers
  void _updateMapFromDataBuffers(Map<String, CircularBuffer> dataBuffers) {
    // Extract GPS position from data buffers
    final latBuffer = dataBuffers['GLOBAL_POSITION_INT.lat'];
    final lonBuffer = dataBuffers['GLOBAL_POSITION_INT.lon'];
    final headingBuffer = dataBuffers['VFR_HUD.heading'];

    if (latBuffer != null &&
        latBuffer.points.isNotEmpty &&
        lonBuffer != null &&
        lonBuffer.points.isNotEmpty) {
      final lat = latBuffer.points.last.value;
      final lon = lonBuffer.points.last.value;
      final heading = headingBuffer != null && headingBuffer.points.isNotEmpty
          ? headingBuffer.points.last.value
          : null;

      final newLocation = LatLng(lat / 1e7, lon / 1e7);

      setState(() {
        _vehicleLocation = newLocation;
        _vehiclePath.add(newLocation);

        // Limit path length based on settings
        final mapSettings = ref.read(mapSettingsProvider);
        if (_vehiclePath.length > mapSettings.maxPathPoints) {
          _vehiclePath.removeAt(0);
        }

        // Update heading if available
        if (heading != null) {
          _vehicleHeading = heading;
        }
      });

      // Auto-follow vehicle if enabled (preserve current zoom level)
      final mapSettings = ref.read(mapSettingsProvider);
      if (mapSettings.followVehicle && _mapReady) {
        final currentZoom = _mapController.camera.zoom;
        _mapController.move(newLocation, currentZoom);
      }
    }
  }

  /// Save current map position and zoom to settings
  void _saveMapState() {
    final camera = _mapController.camera;
    final mapSettings = ref.read(mapSettingsProvider);
    final settingsManager = ref.read(settingsManagerProvider);

    // Always save zoom, but only save position if not following vehicle
    if (mapSettings.followVehicle) {
      // When following vehicle, only save zoom level, keep saved position
      settingsManager.updateMapZoom(camera.zoom);
    } else {
      // When not following, save both position and zoom
      settingsManager.updateMapCenterAndZoom(
        camera.center.latitude,
        camera.center.longitude,
        camera.zoom,
      );
    }
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapSettings = ref.watch(mapSettingsProvider);
    final settingsManager = ref.watch(settingsManagerProvider);
    final defaultCenter = LatLng(
      mapSettings.centerLatitude,
      mapSettings.centerLongitude,
    );
    // Loading map with saved settings

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: defaultCenter,
              initialZoom: mapSettings.zoomLevel,
              minZoom: 5.0,
              maxZoom: 18.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onMapEvent: (MapEvent mapEvent) {
                // Mark map as ready on first event and restore saved position
                if (!_mapReady) {
                  setState(() {
                    _mapReady = true;
                  });
                  // Restore saved position if not following vehicle
                  if (!mapSettings.followVehicle) {
                    Future.microtask(() {
                      _mapController.move(
                        LatLng(
                          mapSettings.centerLatitude,
                          mapSettings.centerLongitude,
                        ),
                        mapSettings.zoomLevel,
                      );
                    });
                  }
                }

                // Save map state when user stops interacting or zooming
                if (mapEvent is MapEventMoveEnd ||
                    mapEvent is MapEventRotateEnd) {
                  _saveMapState();
                }
                // Also save on any zoom or scroll events
                final eventName = mapEvent.runtimeType.toString();
                if (eventName.contains('Zoom') ||
                    eventName.contains('Scroll') ||
                    eventName.contains('Scale') ||
                    eventName.contains('Tap')) {
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) _saveMapState();
                  });
                }
                // Disable following when user manually pans the map
                if (mapEvent is MapEventMoveStart &&
                    mapEvent.source == MapEventSource.onDrag) {
                  if (mapSettings.followVehicle) {
                    settingsManager.updateMapFollowVehicle(false);
                  }
                }
              },
            ),
            children: [
              // Tile layer
              TileLayer(
                urlTemplate: _getTileUrl(),
                userAgentPackageName: 'com.example.js_dash',
              ),

              // Vehicle path layer
              if (mapSettings.showPath && _vehiclePath.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _vehiclePath,
                      strokeWidth: 3.0,
                      color: Colors.blue.withValues(alpha: 0.7),
                    ),
                  ],
                ),

              // Vehicle marker layer
              if (_vehicleLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _vehicleLocation!,
                      width: 40,
                      height: 40,
                      child: Transform.rotate(
                        angle: (_vehicleHeading ?? 0) * math.pi / 180,
                        child: const Icon(
                          Icons.navigation,
                          color: Colors.red,
                          size: 30,
                        ),
                      ),
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
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}';
      case BingMapType.road:
        // OpenStreetMap for roads
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      default:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
  }

  Widget _buildMapControls() {
    final mapSettings = ref.watch(mapSettingsProvider);
    final settingsManager = ref.watch(settingsManagerProvider);

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
                    if (_mapReady) {
                      final currentZoom = _mapController.camera.zoom;
                      final currentCenter = _mapController.camera.center;
                      _mapController.move(currentCenter, currentZoom + 1);
                      // Save the new zoom level immediately
                      Future.delayed(const Duration(milliseconds: 200), () {
                        if (mounted) _saveMapState();
                      });
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.remove, color: Colors.white),
                  onPressed: () {
                    if (_mapReady) {
                      final currentZoom = _mapController.camera.zoom;
                      final currentCenter = _mapController.camera.center;
                      _mapController.move(currentCenter, currentZoom - 1);
                      // Save the new zoom level immediately
                      Future.delayed(const Duration(milliseconds: 200), () {
                        if (mounted) _saveMapState();
                      });
                    }
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
                    mapSettings.showPath
                        ? Icons.timeline
                        : Icons.timeline_outlined,
                    color: mapSettings.showPath ? Colors.blue : Colors.white,
                  ),
                  onPressed: () {
                    settingsManager.updateMapShowPath(
                      !mapSettings.showPath,
                    );
                  },
                  tooltip: mapSettings.showPath ? 'Hide Path' : 'Show Path',
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
                      '${_vehiclePath.length}/${mapSettings.maxPathPoints}',
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
                      mapSettings.followVehicle
                          ? Icons.gps_fixed
                          : Icons.gps_not_fixed,
                      color: mapSettings.followVehicle
                          ? Colors.green
                          : Colors.white,
                    ),
                    onPressed: () {
                      settingsManager.updateMapFollowVehicle(
                        !mapSettings.followVehicle,
                      );
                      // If enabling follow mode, immediately center on vehicle
                      if (!mapSettings.followVehicle &&
                          _vehicleLocation != null &&
                          _mapReady) {
                        _mapController.move(
                          _vehicleLocation!,
                          _mapController.camera.zoom,
                        );
                      }
                    },
                    tooltip: mapSettings.followVehicle
                        ? 'Stop Following Vehicle'
                        : 'Follow Vehicle',
                  ),
                  // Manual center on vehicle button
                  IconButton(
                    icon: const Icon(Icons.my_location, color: Colors.white),
                    onPressed: () {
                      if (_vehicleLocation != null && _mapReady) {
                        _mapController.move(
                          _vehicleLocation!,
                          _mapController.camera.zoom,
                        );
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
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  // Show path configuration dialog
  void _showPathConfigDialog() {
    final mapSettings = ref.read(mapSettingsProvider);
    final settingsManager = ref.read(settingsManagerProvider);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        int tempMaxPathPoints = mapSettings.maxPathPoints;
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
                    settingsManager.updateMapMaxPathPoints(
                      tempMaxPathPoints,
                    );
                    // Trim existing path if it's too long
                    setState(() {
                      while (_vehiclePath.length > tempMaxPathPoints) {
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
