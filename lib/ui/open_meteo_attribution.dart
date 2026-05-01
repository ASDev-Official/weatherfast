import 'package:flutter/material.dart';
import '../webview_screen.dart';

class OpenMeteoAttribution extends StatelessWidget {
  const OpenMeteoAttribution({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.source = 'open-meteo',
  });

  final EdgeInsetsGeometry padding;
  final String source;

  static const String _omHomeUrl = 'https://open-meteo.com/';
  static const String _omDocsUrl = 'https://open-meteo.com/en/docs';
  static const String _omTermsUrl = 'https://open-meteo.com/en/terms';

  static const String _neaUrl = 'https://www.nea.gov.sg/';
  static const String _dataGovUrl = 'https://data.gov.sg/';

  static void _openLink(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => WebViewScreen(url: url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNea = source == 'nea';

    return Padding(
      padding: padding,
      child: Card(
        margin: const EdgeInsets.only(top: 4, bottom: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isNea
                    ? 'Weather data provided by National Environment Agency Singapore'
                    : 'Weather data provided by Open-Meteo',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: isNea
                    ? [
                        ActionChip(
                          label: const Text('Website'),
                          avatar: const Icon(Icons.public, size: 16),
                          onPressed: () => _openLink(context, _neaUrl),
                        ),
                        ActionChip(
                          label: const Text('API Docs'),
                          avatar: const Icon(Icons.menu_book_outlined, size: 16),
                          onPressed: () => _openLink(context, _dataGovUrl),
                        ),
                      ]
                    : [
                        ActionChip(
                          label: const Text('Website'),
                          avatar: const Icon(Icons.public, size: 16),
                          onPressed: () => _openLink(context, _omHomeUrl),
                        ),
                        ActionChip(
                          label: const Text('API Docs'),
                          avatar: const Icon(Icons.menu_book_outlined, size: 16),
                          onPressed: () => _openLink(context, _omDocsUrl),
                        ),
                        ActionChip(
                          label: const Text('Terms'),
                          avatar: const Icon(Icons.gavel_outlined, size: 16),
                          onPressed: () => _openLink(context, _omTermsUrl),
                        ),
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
