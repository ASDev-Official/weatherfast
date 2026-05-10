import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WeatherMapView extends StatelessWidget {
  final double initialLat;
  final double initialLng;
  final double radarOpacity;

  const WeatherMapView({
    super.key,
    required this.initialLat,
    required this.initialLng,
    required this.radarOpacity,
  });

  Future<void> _launchPlayStore() async {
    final url = Uri.parse("https://play.google.com/store/apps/details?id=com.aadishsamir.weatherfast");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_rounded, 
              size: 80, 
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              "Weather Maps Unavailable on Web",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Interactive weather radar and high-resolution maps are optimized for our mobile experience.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _launchPlayStore,
              icon: const Icon(Icons.shop_rounded),
              label: const Text("Get it on Play Store"),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
