import 'package:flutter_map/flutter_map.dart';
import 'bing_maps_service.dart';

/// Simple helper to create Bing Maps compatible tile URLs for flutter_map
class BingMapsHelper {
  /// Create a TileLayer for Bing Maps
  static TileLayer createTileLayer(BingMapType mapType, {String? userAgent}) {
    return TileLayer(
      urlTemplate: _getUrlTemplate(mapType),
      userAgentPackageName: userAgent ?? 'js_dash_flutter_app',
      additionalOptions: {
        'mapType': mapType.apiName,
      },
    );
  }
  
  /// Get URL template based on map type
  /// Note: These are fallback URLs. For production, you should use the Bing Maps API
  static String _getUrlTemplate(BingMapType mapType) {
    switch (mapType) {
      case BingMapType.aerial:
        // Bing Aerial (satellite) tiles
        return 'https://ecn.t{s}.tiles.virtualearth.net/tiles/a{q}.jpeg?g=1';
      case BingMapType.aerialWithLabels:
        // Bing Hybrid (satellite + labels) tiles  
        return 'https://ecn.t{s}.tiles.virtualearth.net/tiles/h{q}.jpeg?g=1';
      case BingMapType.road:
        // Bing Road tiles
        return 'https://ecn.t{s}.tiles.virtualearth.net/tiles/r{q}.jpeg?g=1';
      default:
        // Default to aerial
        return 'https://ecn.t{s}.tiles.virtualearth.net/tiles/a{q}.jpeg?g=1';
    }
  }
  
  /// Convert tile coordinates to quadkey for Bing Maps
  static String tileToQuadKey(int x, int y, int z) {
    final quadKey = StringBuffer();
    for (int i = z; i > 0; i--) {
      int digit = 0;
      final mask = 1 << (i - 1);
      if ((x & mask) != 0) {
        digit++;
      }
      if ((y & mask) != 0) {
        digit += 2;
      }
      quadKey.write(digit);
    }
    return quadKey.toString();
  }
}