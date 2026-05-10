import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapboxService {
  static void setToken(String token) {
    MapboxOptions.setAccessToken(token);
  }
}
