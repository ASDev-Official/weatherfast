import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/preferences_service.dart';

class WeatherMapView extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final double radarOpacity;

  const WeatherMapView({
    super.key,
    required this.initialLat,
    required this.initialLng,
    required this.radarOpacity,
  });

  @override
  State<WeatherMapView> createState() => _WeatherMapViewState();
}

class _WeatherMapViewState extends State<WeatherMapView> {
  MapboxMap? _mapboxMap;
  bool _isLoading = true;

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
  }

  void _onStyleLoaded(StyleLoadedEventData event) async {
    await _addWeatherLayer();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _addWeatherLayer() async {
    if (_mapboxMap == null) return;
    try {
      final response = await http.get(Uri.parse("https://api.rainviewer.com/public/weather-maps.json"));
      final config = jsonDecode(response.body);
      final List past = config['radar']?['past'] ?? [];
      if (past.isEmpty) return;

      final latestRadar = past.last;
      final path = latestRadar['path'];
      final host = config['host'] ?? "https://tilecache.rainviewer.com";
      final radarUrl = "$host$path/256/{z}/{x}/{y}/2/1_1.png";

      try {
        await _mapboxMap?.style.removeStyleLayer("weather-layer");
        await _mapboxMap?.style.removeStyleSource("weather-source");
      } catch (_) {}

      await _mapboxMap?.style.addSource(
        RasterSource(
          id: "weather-source",
          tiles: [radarUrl],
          tileSize: 256,
          minzoom: 0.0,
          maxzoom: 7.0, 
        ),
      );

      await _mapboxMap?.style.addLayer(
        RasterLayer(
          id: "weather-layer",
          sourceId: "weather-source",
        ),
      );
      
      await _mapboxMap?.style.setStyleLayerProperty("weather-layer", "raster-opacity", widget.radarOpacity);
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  void didUpdateWidget(WeatherMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.radarOpacity != widget.radarOpacity && _mapboxMap != null) {
      _mapboxMap?.style.setStyleLayerProperty("weather-layer", "raster-opacity", widget.radarOpacity);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapWidget(
          key: const ValueKey("mapWidget"),
          onMapCreated: _onMapCreated,
          onStyleLoadedListener: _onStyleLoaded,
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(widget.initialLng, widget.initialLat)),
            zoom: 5.0,
          ),
          styleUri: MapboxStyles.MAPBOX_STREETS,
        ),
        if (_isLoading)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
