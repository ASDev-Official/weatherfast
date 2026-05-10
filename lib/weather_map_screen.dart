import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/preferences_service.dart';
import 'package:flutter/foundation.dart';

// Conditional imports to prevent Mapbox SDK crashes on Web
// This ensures that the 'mapbox_maps_flutter' package is NEVER loaded in the browser.
import 'ui/weather_map_view_mobile.dart'
    if (dart.library.html) 'ui/weather_map_view_web.dart';

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
  bool _settingsLoaded = false;
  double _radarOpacity = 0.7;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final opacity = await PreferencesService.loadMapRadarOpacity();
    if (mounted) {
      setState(() {
        _radarOpacity = opacity;
        _settingsLoaded = true;
      });
    }
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
                      setState(() => _radarOpacity = val);
                      PreferencesService.saveMapRadarOpacity(val);
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
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              onPressed: _showSettings,
            ),
        ],
      ),
      body: _settingsLoaded
          ? WeatherMapView(
              initialLat: widget.initialLat,
              initialLng: widget.initialLng,
              radarOpacity: _radarOpacity,
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
