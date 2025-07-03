import 'dart:async';
import 'data_provider.dart';
import '../base/dashboard_config.dart';
import '../../../services/mavlink_spoof_service.dart';

/// MAVLink data provider that integrates with the spoof service
class MavlinkDataProvider extends DataProvider {
  final MavlinkSpoofService _spoofService;
  final Map<String, StreamController<dynamic>> _controllers = {};
  final List<StreamSubscription> _subscriptions = [];
  Map<String, dynamic> _currentData = {};
  
  MavlinkDataProvider(this._spoofService) {
    _subscribeToService();
  }
  
  void _subscribeToService() {
    // Subscribe to VFR HUD for RPM and speed data
    _subscriptions.add(
      _spoofService.vfrHudStream.listen((vfrHud) {
        // Convert throttle to RPM (0-100% -> 800-6500 RPM)
        final rpm = 800 + (vfrHud.throttle / 100.0) * 5700;
        _updateValue('rpm', rpm);
        
        // Convert airspeed to km/h
        final speedKmh = vfrHud.airspeed * 3.6;
        _updateValue('speed', speedKmh);
        
        _updateValue('throttle', vfrHud.throttle);
        _updateValue('altitude', vfrHud.alt);
        _updateValue('heading', vfrHud.heading);
      }),
    );
    
    // Subscribe to attitude for wing positions
    _subscriptions.add(
      _spoofService.attitudeStream.listen((attitude) {
        // Convert roll to wing positions (radians to degrees)
        final rollDegrees = attitude.roll * 180 / 3.14159;
        _updateValue('leftWingAngle', -rollDegrees);
        _updateValue('rightWingAngle', rollDegrees);
        
        _updateValue('roll', attitude.roll);
        _updateValue('pitch', attitude.pitch);
        _updateValue('yaw', attitude.yaw);
      }),
    );
    
    // Use spoof service getters for direct access
    _updateValue('rpm', _spoofService.currentRPM);
    _updateValue('speed', _spoofService.currentSpeed * 3.6); // m/s to km/h
    _updateValue('leftWingAngle', _spoofService.portWingPosition);
    _updateValue('rightWingAngle', _spoofService.starboardWingPosition);
  }
  
  void _updateValue(String field, dynamic value) {
    _currentData[field] = value;
    _controllers[field]?.add(value);
  }
  
  @override
  Stream<dynamic> getDataStream(DataBinding binding) {
    // Create controller if it doesn't exist
    _controllers[binding.field] ??= StreamController<dynamic>.broadcast();
    
    // Return the stream, applying transformer if provided
    final stream = _controllers[binding.field]!.stream;
    
    if (binding.transformer != null) {
      return stream.map(binding.transformer!);
    }
    
    return stream;
  }
  
  @override
  dynamic getCurrentValue(DataBinding binding) {
    var value = _currentData[binding.field];
    
    // Handle field mappings
    if (value == null) {
      switch (binding.field) {
        case 'leftWingAngle':
          value = _currentData['leftWingPosition'];
          break;
        case 'rightWingAngle':
          value = _currentData['rightWingPosition'];
          break;
      }
    }
    
    // Apply transformer if provided
    if (value != null && binding.transformer != null) {
      return binding.transformer!(value);
    }
    
    return value;
  }
  
  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }
}