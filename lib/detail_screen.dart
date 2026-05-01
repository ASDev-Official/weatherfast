import 'package:flutter/material.dart';

import 'services/global_data.dart';
import 'services/weather_insights_service.dart';
import 'time_service.dart';
import 'ui/animated_weather_backdrop.dart';
import 'weather_service.dart';

class DetailScreen extends StatefulWidget {
  final String? location;

  const DetailScreen({super.key, required this.location});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen>
    with SingleTickerProviderStateMixin {
  final WeatherService _weatherService = WeatherService();
  final TimeService _timeService = TimeService();
  final WeatherInsightsService _insightsService = WeatherInsightsService();

  bool _isDaytime = true;
  String _condition = 'Clear';
  int? _tempC;
  int? _hiC;
  int? _loC;
  String? _locationName;
  bool _isLoading = true;
  int? _aqi;
  String _aqiText = '';

  // Comprehensive insights data
  List<String> _recommendations = [];
  String _insightsSummary = '';
  List<Map<String, String>> _activities = [];
  List<Map<String, String>> _healthTips = [];
  Map<String, String> _clothingAdvice = {};
  List<Map<String, dynamic>> _hourlyInsights = [];
  Map<String, String> _weekAhead = {};
  Map<String, String> _bestTimes = {};

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    // Fetch immediately if location is available
    _attemptFetch();
  }

  void _attemptFetch() {
    final loc = widget.location?.trim() ?? '';
    if (loc.isNotEmpty) {
      setState(() => _isLoading = true);
      Future.microtask(() {
        _fetchForecast();
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void didUpdateWidget(DetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Fetch when location changes
    if (widget.location != oldWidget.location) {
      _attemptFetch();
    }
  }

  Future<void> _fetchForecast() async {
    final loc = widget.location?.trim() ?? '';
    if (loc.isEmpty) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _weatherService.fetchForecast(widget.location!);

      final current = data['current'] ?? {};
      final today =
          _firstOrNull(data['forecast']?['forecastday'] as List?) as Map?;
      final tz = data['location']?['tz_id'] as String?;

      bool isDaytime = true;
      if (tz != null && tz.isNotEmpty) {
        final timeData = await _timeService.getTimeForLocation(tz);
        isDaytime = timeData['isDaytime'] as bool? ?? true;
      }

      if (!mounted) return;
      setState(() {
        _condition = current['condition']?['text'] ?? 'Clear';
        _tempC = (current['temp_c'] as num?)?.round();
        _hiC = (today?['day']?['maxtemp_c'] as num?)?.round();
        _loC = (today?['day']?['mintemp_c'] as num?)?.round();
        _locationName = data['location']?['name'] ?? widget.location;
        _isDaytime = isDaytime;
        _aqi = (current['aqi'] as num?)?.toInt();
        _aqiText = current['air_quality_text']?.toString() ?? '';
        _isLoading = false;
      });
      _controller.forward(from: 0);

      // Generate insights after successful data fetch
      _generateInsights(data);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load Insights: $e')));
      }
    }
  }

  void _generateInsights(Map<String, dynamic> forecastData) {
    try {
      final current = forecastData['current'] ?? {};
      final dailyForecasts =
          (forecastData['forecast']?['forecastday'] as List?) ?? [];
      final country = forecastData['location']?['country']?.toString() ?? '';

      final insights = _insightsService.generateInsights(
        condition: _condition,
        currentTemp: _tempC ?? 0,
        highTemp: _hiC ?? 0,
        lowTemp: _loC ?? 0,
        humidity: (current['humidity'] as num?)?.toInt() ?? 0,
        windSpeed: (current['wind_kph'] as num?)?.toDouble() ?? 0.0,
        uvIndex: (current['uv'] as num?)?.toDouble() ?? 0.0,
        aqi: _aqi ?? 0,
        dailyForecasts: dailyForecasts.cast<Map<String, dynamic>>(),
        country: country,
      );

      if (mounted) {
        setState(() {
          _insightsSummary = insights['summary'] as String;
          _recommendations = (insights['recommendations'] as List)
              .cast<String>();
          _activities = (insights['activities'] as List)
              .cast<Map<String, String>>();
          _healthTips = (insights['healthTips'] as List)
              .cast<Map<String, String>>();
          _clothingAdvice = (insights['clothingAdvice'] as Map)
              .cast<String, String>();
          _hourlyInsights = (insights['hourlyInsights'] as List)
              .cast<Map<String, dynamic>>();
          _weekAhead = (insights['weekAhead'] as Map).cast<String, String>();
          _bestTimes = (insights['bestTimes'] as Map).cast<String, String>();
        });
      }
    } catch (e) {
      // Insights generation failed, continue without them
    }
  }

  Widget _buildAIInsightsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(
                    context,
                  ).colorScheme.tertiaryContainer.withValues(alpha: 0.6),
                  Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.4),
                ],
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Weather Insights',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Summary
                Text(
                  _insightsSummary.isEmpty
                      ? 'Analyzing conditions...'
                      : _insightsSummary,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                if (_aqi != null && _aqi! > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.air_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Air Quality',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_aqi • ${_aqiText.isNotEmpty ? _aqiText : 'AQI'}',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_recommendations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // Recommendations
                  ..._recommendations.map(
                    (rec) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              rec,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCards() {
    if (_activities.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.directions_walk,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Activity Suggestions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._activities.asMap().entries.map((entry) {
                final idx = entry.key;
                final activity = entry.value;
                final isLast = idx == _activities.length - 1;
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity['icon'] ?? '🌤️',
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activity['title'] ?? '',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                activity['description'] ?? '',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!isLast) ...[
                      const SizedBox(height: 12),
                      Divider(
                        height: 1,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthTipsCard() {
    if (_healthTips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.health_and_safety,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Health & Safety',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._healthTips.map((tip) {
                final severity = tip['severity'] ?? 'low';
                Color indicatorColor;
                if (severity == 'high') {
                  indicatorColor = Theme.of(context).colorScheme.error;
                } else if (severity == 'medium') {
                  indicatorColor = Colors.orange;
                } else {
                  indicatorColor = Colors.green;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: indicatorColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tip['icon'] ?? '',
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tip['title'] ?? '',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: indicatorColor,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tip['description'] ?? '',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClothingCard() {
    if (_clothingAdvice.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                _clothingAdvice['icon'] ?? '👕',
                style: const TextStyle(fontSize: 40),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What to Wear',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _clothingAdvice['advice'] ?? '',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHourlyInsightsCard() {
    if (_hourlyInsights.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today\'s Timeline',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ..._hourlyInsights.map((insight) {
                final tempC = (insight['temp'] as num?)?.toDouble() ?? 0;
                final displayTemp = GlobalData.useFahrenheit
                    ? ((tempC * 9 / 5) + 32).round()
                    : tempC.round();
                final unit = GlobalData.useFahrenheit ? 'F' : 'C';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            insight['time'] ?? '',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$displayTemp°$unit',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          insight['insight'] ?? '',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekAheadCard() {
    if (_weekAhead.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_month,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Week Ahead',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _weekAhead['summary'] ?? '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBestTimesCard() {
    if (_bestTimes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wb_sunny,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _bestTimes['title'] ?? '',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _bestTimes['description'] ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    PreferredSizeWidget animatedAppBar({required Widget child}) {
      return PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Stack(
          children: [
            Container(
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.85),
                    brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              titleSpacing: 16,
              title: child,
            ),
          ],
        ),
      );
    }

    if (widget.location == null || widget.location!.isEmpty) {
      return Scaffold(
        appBar: animatedAppBar(child: const Text('Weather Insights')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Select a location from Home',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'to view the detailed Insights',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: animatedAppBar(child: const Text('Insights')),
        body: const SafeArea(
          child: Column(
            children: [
              Spacer(),
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading weather insights...'),
              Spacer(),
            ],
          ),
        ),
      );
    }

    final condition = _condition;
    final isDaytime = _isDaytime;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: animatedAppBar(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10), // Top spacing
            const Text('Weather Insights'),
            if (_locationName != null)
              Text(
                _locationName!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ),
      body: Stack(
        children: [
          AnimatedWeatherBackdrop(
            condition: condition,
            isDaytime: isDaytime,
            height: 320,
            intensity: 0.6,
          ),
          SafeArea(
            child: RefreshIndicator.adaptive(
              onRefresh: _fetchForecast,
              displacement: 32,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          // AI Insights only - no duplicate home page content
                          SliverToBoxAdapter(child: _buildAIInsightsCard()),
                          SliverToBoxAdapter(child: _buildActivityCards()),
                          SliverToBoxAdapter(child: _buildClothingCard()),
                          SliverToBoxAdapter(child: _buildBestTimesCard()),
                          SliverToBoxAdapter(child: _buildHourlyInsightsCard()),
                          SliverToBoxAdapter(child: _buildHealthTipsCard()),
                          SliverToBoxAdapter(child: _buildWeekAheadCard()),

                          const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

dynamic _firstOrNull(List? list) {
  if (list == null || list.isEmpty) return null;
  return list.first;
}
