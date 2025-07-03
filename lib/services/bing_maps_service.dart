import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class BingMapsService {
  static const String _baseUrl = 'http://dev.virtualearth.net/REST/v1/Imagery/Metadata';
  
  // You need to get your own Bing Maps API key from:
  // https://www.bingmapsportal.com/
  static const String _apiKey = 'YOUR_BING_MAPS_API_KEY_HERE';
  
  // Cache for tile URL templates
  static final Map<BingMapType, BingMapMetadata> _metadataCache = {};
  
  /// Get tile URL template for the specified map type
  static Future<String?> getTileUrlTemplate(BingMapType mapType) async {
    // Check cache first
    if (_metadataCache.containsKey(mapType)) {
      return _metadataCache[mapType]?.urlTemplate;
    }
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/${mapType.apiName}?output=json&include=ImageryProviders&key=$_apiKey'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['statusCode'] == 200 && data['resourceSets'].isNotEmpty) {
          final resource = data['resourceSets'][0]['resources'][0];
          final urlTemplate = resource['imageUrl'] as String;
          final subdomains = List<String>.from(resource['imageUrlSubdomains']);
          
          final metadata = BingMapMetadata(
            urlTemplate: urlTemplate,
            subdomains: subdomains,
            zoomMin: resource['zoomMin'] ?? 1,
            zoomMax: resource['zoomMax'] ?? 21,
          );
          
          _metadataCache[mapType] = metadata;
          return urlTemplate;
        }
      }
    } catch (e) {
      debugPrint('Error fetching Bing Maps metadata: $e');
    }
    
    return null;
  }
  
  /// Get tile URL for specific coordinates
  static Future<String?> getTileUrl(BingMapType mapType, int x, int y, int z) async {
    final template = await getTileUrlTemplate(mapType);
    if (template == null) return null;
    
    final metadata = _metadataCache[mapType];
    if (metadata == null) return null;
    
    final quadkey = _tileXYToQuadKey(x, y, z);
    final subdomain = metadata.subdomains[Random().nextInt(metadata.subdomains.length)];
    
    return template
        .replaceAll('{subdomain}', subdomain)
        .replaceAll('{quadkey}', quadkey);
  }
  
  /// Convert tile coordinates to quadkey (Bing Maps specific)
  static String _tileXYToQuadKey(int tileX, int tileY, int levelOfDetail) {
    final quadKey = StringBuffer();
    for (int i = levelOfDetail; i > 0; i--) {
      int digit = 0;
      final mask = 1 << (i - 1);
      if ((tileX & mask) != 0) {
        digit++;
      }
      if ((tileY & mask) != 0) {
        digit += 2;
      }
      quadKey.write(digit);
    }
    return quadKey.toString();
  }
  
  /// Check if API key is configured
  static bool get isConfigured => _apiKey != 'YOUR_BING_MAPS_API_KEY_HERE';
  
  /// Clear metadata cache (useful for testing)
  static void clearCache() {
    _metadataCache.clear();
  }
}

enum BingMapType {
  aerial('Aerial'),
  aerialWithLabels('AerialWithLabelsOnDemand'),
  road('RoadOnDemand'),
  canvasDark('CanvasDark'),
  canvasLight('CanvasLight'),
  canvasGray('CanvasGray');
  
  const BingMapType(this.apiName);
  final String apiName;
  
  String get displayName {
    switch (this) {
      case BingMapType.aerial:
        return 'Satellite';
      case BingMapType.aerialWithLabels:
        return 'Hybrid';
      case BingMapType.road:
        return 'Road';
      case BingMapType.canvasDark:
        return 'Dark';
      case BingMapType.canvasLight:
        return 'Light';
      case BingMapType.canvasGray:
        return 'Gray';
    }
  }
}

class BingMapMetadata {
  final String urlTemplate;
  final List<String> subdomains;
  final int zoomMin;
  final int zoomMax;
  
  const BingMapMetadata({
    required this.urlTemplate,
    required this.subdomains,
    required this.zoomMin,
    required this.zoomMax,
  });
}