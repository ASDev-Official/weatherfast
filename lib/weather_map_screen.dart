import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'services/preferences_service.dart';

class WeatherMapScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const WeatherMapScreen({
    super.key,
    this.initialLat = 0,
    this.initialLng = 0,
  });

  @override
  State<WeatherMapScreen> createState() => _WeatherMapScreenState();
}

class _WeatherMapScreenState extends State<WeatherMapScreen> {
  MapboxMap? _mapboxMap;
  bool _isLoading = true;
  bool _settingsLoaded = false;
  
  // Settings state
  double _radarOpacity = 0.7;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final token = dotenv.get('MAPBOX_ACCESS_TOKEN', fallback: '');
    if (token.isNotEmpty) {
      MapboxOptions.setAccessToken(token);
    }
    
    final opacity = await PreferencesService.loadMapRadarOpacity();
    
    if (mounted) {
      setState(() {
        _radarOpacity = opacity;
        _settingsLoaded = true;
      });
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
  }

  void _onStyleLoaded(StyleLoadedEventData event) async {
    debugPrint("Mapbox style loaded");
    await _addWeatherLayer();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addWeatherLayer() async {
    try {
      final response = await http.get(Uri.parse("https://api.rainviewer.com/public/weather-maps.json"));
      if (response.statusCode != 200) throw Exception("Failed to fetch RainViewer config");
      
      final config = jsonDecode(response.body);
      final List past = config['radar']?['past'] ?? [];
      if (past.isEmpty) throw Exception("No radar data available");

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

      try {
        await _mapboxMap?.style.setStyleSourceProperty("weather-source", "maxzoom", 7.0);
        await _mapboxMap?.style.setStyleSourceProperty("weather-source", "minzoom", 0.0);
      } catch (_) {}

      await _mapboxMap?.style.addLayer(
        RasterLayer(
          id: "weather-layer",
          sourceId: "weather-source",
        ),
      );
      
      await _mapboxMap?.style.setStyleLayerProperty("weather-layer", "raster-opacity", _radarOpacity);
      
      debugPrint("Weather layer added using path: $path");
    } catch (e) {
      debugPrint("Error adding weather layer: $e");
    }
  }

  void _updateOpacity(double value) async {
    setState(() {
      _radarOpacity = value;
    });
    await PreferencesService.saveMapRadarOpacity(value);
    await _mapboxMap?.style.setStyleLayerProperty("weather-layer", "raster-opacity", _radarOpacity);
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Map Settings", style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text("Radar Opacity", style: Theme.of(context).textTheme.labelLarge),
                  ),
                  Slider(
                    value: _radarOpacity,
                    onChanged: (val) {
                      setModalState(() => _radarOpacity = val);
                      _updateOpacity(val);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text("Data Sources"),
                    onTap: () {
                      Navigator.pop(context);
                      _showSources();
                    },
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _showSources() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Data Sources"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Map Layers:", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("Base maps are provided by Mapbox."),
            SizedBox(height: 12),
            Text("Weather Data:", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("Live precipitation radar layers are provided by RainViewer."),
            SizedBox(height: 12),
            Text("Attribution:", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("© Mapbox, © OpenStreetMap contributors, © RainViewer."),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_settingsLoaded)
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
          if (!_settingsLoaded || _isLoading)
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text("Updating map..."),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class WeatherMapSnippet extends StatelessWidget {
  final double lat;
  final double lng;
  final VoidCallback onTap;

  const WeatherMapSnippet({
    super.key,
    required this.lat,
    required this.lng,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            IgnorePointer(
              child: MapWidget(
                key: const ValueKey("snippetMap"),
                cameraOptions: CameraOptions(
                  center: Point(coordinates: Position(lng, lat)),
                  zoom: 4.0,
                ),
                styleUri: MapboxStyles.MAPBOX_STREETS,
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.4),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.map_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Weather Map',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Tap to view interactive radar',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
