import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';

import 'global_data.dart';
import 'preferences_service.dart';
import 'weather_cache_service.dart';
import '../weather_service.dart';

const String _refreshTaskName = 'weatherfast_widget_refresh';
const String _periodicRefreshId = 'weatherfast_widget_refresh_periodic';

const String _kLocationQuery = 'wf_location_query';
const String _kLocationName = 'wf_location_name';
const String _kConditionText = 'wf_condition_text';
const String _kTemperature = 'wf_temperature';
const String _kHighLow = 'wf_high_low';
const String _kUpdatedAt = 'wf_updated_at';
const String _kConditionGlyph = 'wf_condition_glyph';
const String _kFeelsLike = 'wf_feels_like';
const String _kHumidity = 'wf_humidity';
const String _kWind = 'wf_wind';
const String _kAqi = 'wf_aqi';
const String _kDayName1 = 'wf_day_name_1';
const String _kDayName2 = 'wf_day_name_2';
const String _kDayName3 = 'wf_day_name_3';
const String _kDayName4 = 'wf_day_name_4';
const String _kDayName5 = 'wf_day_name_5';
const String _kDayName6 = 'wf_day_name_6';
const String _kDayName7 = 'wf_day_name_7';
const String _kDayTemp1 = 'wf_day_temp_1';
const String _kDayTemp2 = 'wf_day_temp_2';
const String _kDayTemp3 = 'wf_day_temp_3';
const String _kDayTemp4 = 'wf_day_temp_4';
const String _kDayTemp5 = 'wf_day_temp_5';
const String _kDayTemp6 = 'wf_day_temp_6';
const String _kDayTemp7 = 'wf_day_temp_7';
const String _kDayIcon1 = 'wf_day_icon_1';
const String _kDayIcon2 = 'wf_day_icon_2';
const String _kDayIcon3 = 'wf_day_icon_3';
const String _kDayIcon4 = 'wf_day_icon_4';
const String _kDayIcon5 = 'wf_day_icon_5';
const String _kDayIcon6 = 'wf_day_icon_6';
const String _kDayIcon7 = 'wf_day_icon_7';

@pragma('vm:entry-point')
void widgetRefreshCallbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (task == _refreshTaskName) {
      await WidgetRefreshService.refreshFromBackground();
    }
    return true;
  });
}

class WidgetRefreshService {
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    await Workmanager().initialize(
      widgetRefreshCallbackDispatcher,
      isInDebugMode: false,
    );

    await Workmanager().registerPeriodicTask(
      _periodicRefreshId,
      _refreshTaskName,
      frequency: const Duration(minutes: 15),
      initialDelay: const Duration(minutes: 5),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.connected),
    );

    _isInitialized = true;
  }

  static Future<void> storeAndRefresh({
    required Map<String, dynamic> weatherData,
    required bool useFahrenheit,
  }) async {
    if (kIsWeb) {
      return;
    }

    final locationName = (weatherData['location']?['name'] ?? '').toString();
    final condition =
        (weatherData['current']?['condition']?['text'] ?? 'Unknown').toString();
    final source = (weatherData['source'] ?? 'open-meteo').toString();

    final num? tempValue = useFahrenheit
        ? (weatherData['current']?['temp_f'] as num?)
        : (weatherData['current']?['temp_c'] as num?);
    // ... rest of data extraction ...
    
    // We can save source if we want widgets to show it, but for now we just 
    // ensure the data fetched is correct.
    await HomeWidget.saveWidgetData<String>('wf_source', source);
    final num? feelsLikeValue = useFahrenheit
        ? (weatherData['current']?['feelslike_f'] as num?)
        : (weatherData['current']?['feelslike_c'] as num?);
    final int? humidity = weatherData['current']?['humidity'] as int?;
    final num? windKph = weatherData['current']?['wind_kph'] as num?;
    final int? aqi = weatherData['current']?['aqi'] as int?;
    final nextHoursRaw =
        weatherData['widget_next_hours'] as List<dynamic>? ?? const [];
    final nextDaysRaw =
        weatherData['widget_next_days'] as List<dynamic>? ?? const [];
    final num? highValue = useFahrenheit
        ? (weatherData['widget_today_high_f'] as num?)
        : (weatherData['widget_today_high_c'] as num?);
    final num? lowValue = useFahrenheit
        ? (weatherData['widget_today_low_f'] as num?)
        : (weatherData['widget_today_low_c'] as num?);

    final unit = useFahrenheit ? 'F' : 'C';
    final tempLabel = tempValue == null
        ? '-- $unit'
        : '${tempValue.round()} $unit';

    final hourlyLabels = <String>[];
    final hourlyIcons = <String>[];
    final hourlyTemps = <String>[];
    final hourlyConditions = <String>[];
    String? hourlySourceTransition;
    String? lastHourlySource;

    for (final item in nextHoursRaw) {
      if (item is! Map) {
        continue;
      }

      final displayTime = item['display_time']?.toString() ?? '';
      final timeRaw = item['time']?.toString() ?? '';
      final parsedTime = DateTime.tryParse(timeRaw);
      final source = item['source']?.toString() ?? 'nea';
      final conditionText = item['condition']?['text']?.toString() ?? '';

      if (lastHourlySource != null && lastHourlySource != source && hourlySourceTransition == null) {
        hourlySourceTransition = source == 'open-meteo' ? 'Data from Open-Meteo' : 'Data from NEA';
      }
      lastHourlySource = source;

      if (displayTime.isNotEmpty) {
        // Handle NEA Ranged Periods for Singapore - using 2 forecast spaces
        String from = displayTime;
        String to = '';
        if (displayTime.contains(' to ')) {
          final parts = displayTime.split(' to ');
          from = parts[0].trim();
          to = parts[1].trim();
        }

        String parseTimeShort(String t) {
          if (t.toLowerCase().contains('midday')) return '12 PM';
          if (t.toLowerCase().contains('midnight')) return '12 AM';
          final match = RegExp(r'(\d{1,2})\s*([aApP][mM])').firstMatch(t);
          if (match != null) {
            return '${match.group(1)} ${match.group(2)!.toUpperCase()}';
          }
          // Fallback if parsing fails
          return t.length > 8 ? t.substring(0, 8) : t;
        }

        final fromLabel = parseTimeShort(from);
        final toLabel = to.isNotEmpty ? parseTimeShort(to) : '';

        // Space 1: From
        hourlyTemps.add('From');
        hourlyLabels.add(fromLabel);
        hourlyIcons.add(
          item['glyph']?.toString() ??
              _glyphForCondition(conditionText),
        );
        hourlyConditions.add(conditionText);

        // Space 2: To
        if (hourlyLabels.length < 24 && toLabel.isNotEmpty) {
          hourlyTemps.add('To');
          hourlyLabels.add(toLabel);
          hourlyIcons.add(
            item['glyph']?.toString() ??
                _glyphForCondition(conditionText),
          );
          hourlyConditions.add(conditionText);
        }
      } else if (parsedTime != null) {
        // Standard Hourly
        final hourLabel = _formatHourLabel(parsedTime);
        final num? hourTempValue = useFahrenheit
            ? item['temp_f'] as num?
            : item['temp_c'] as num?;
        final hourTemp = hourTempValue == null
            ? '--'
            : '${hourTempValue.round()}°';
        hourlyLabels.add(hourLabel);
        hourlyTemps.add(hourTemp);
        hourlyIcons.add(
          item['glyph']?.toString() ??
              _glyphForCondition(conditionText),
        );
        hourlyConditions.add(conditionText);
      } else {
        continue;
      }

      if (hourlyLabels.length >= 24) {
        break;
      }
    }

    final dayNames = <String>[];
    final dayTemps = <String>[];
    final dayIcons = <String>[];
    String? dailySourceTransition;
    String? lastDailySource;

    for (final item in nextDaysRaw) {
      if (item is! Map) {
        continue;
      }

      final dateRaw = item['date']?.toString() ?? '';
      final parsed = DateTime.tryParse(dateRaw);
      final dayName = parsed == null ? '--' : _weekdayLabel(parsed.weekday);
      final source = item['source']?.toString() ?? 'nea';

      if (lastDailySource != null && lastDailySource != source && dailySourceTransition == null) {
        dailySourceTransition = source == 'open-meteo' ? 'Data from Open-Meteo' : 'Data from NEA';
      }
      lastDailySource = source;

      final num? maxValue = useFahrenheit
          ? item['max_f'] as num?
          : item['max_c'] as num?;
      final num? minValue = useFahrenheit
          ? item['min_f'] as num?
          : item['min_c'] as num?;

      dayNames.add(dayName);
      if (maxValue == null || minValue == null) {
        dayTemps.add('-- / --');
      } else {
        dayTemps.add('${maxValue.round()}$unit / ${minValue.round()}$unit');
      }
      dayIcons.add(
        item['glyph']?.toString() ??
            _glyphForCondition(item['condition']?['text']?.toString() ?? ''),
      );

      if (dayNames.length >= 7) {
        break;
      }
    }

    await HomeWidget.saveWidgetData<String>(_kLocationQuery, locationName);
    await HomeWidget.saveWidgetData<String>(_kLocationName, locationName);
    await HomeWidget.saveWidgetData<String>(_kConditionText, condition);
    await HomeWidget.saveWidgetData<String>(_kTemperature, tempLabel);
    await HomeWidget.saveWidgetData<String>(
      _kHighLow,
      (highValue == null || lowValue == null)
          ? '-- / --'
          : '${highValue.round()}$unit / ${lowValue.round()}$unit',
    );
    await HomeWidget.saveWidgetData<String>(
      _kFeelsLike,
      feelsLikeValue == null ? '--' : '${feelsLikeValue.round()} $unit',
    );
    await HomeWidget.saveWidgetData<String>(
      _kHumidity,
      humidity == null ? '--' : '$humidity%',
    );
    await HomeWidget.saveWidgetData<String>(
      _kWind,
      windKph == null ? '--' : '${windKph.round()} km/h',
    );
    await HomeWidget.saveWidgetData<String>(_kAqi, aqi == null ? '--' : '$aqi');

    for (int index = 1; index <= 24; index++) {
      await HomeWidget.saveWidgetData<String>(
        'wf_hour_$index',
        hourlyLabels.length >= index ? hourlyLabels[index - 1] : '--',
      );
      await HomeWidget.saveWidgetData<String>(
        'wf_hour_icon_$index',
        hourlyIcons.length >= index ? hourlyIcons[index - 1] : 'partly',
      );
      await HomeWidget.saveWidgetData<String>(
        'wf_hour_temp_$index',
        hourlyTemps.length >= index ? hourlyTemps[index - 1] : '--',
      );
      await HomeWidget.saveWidgetData<String>(
        'wf_hour_condition_$index',
        hourlyConditions.length >= index ? hourlyConditions[index - 1] : '',
      );
    }
    await HomeWidget.saveWidgetData<String>(
      _kDayName1,
      dayNames.isNotEmpty ? dayNames[0] : '--',
    );
    await HomeWidget.saveWidgetData<String>(
      _kDayName2,
      dayNames.length > 1 ? dayNames[1] : '--',
    );
    await HomeWidget.saveWidgetData<String>(
      _kDayName3,
      dayNames.length > 2 ? dayNames[2] : '--',
    );
    await HomeWidget.saveWidgetData<String>(
      _kDayName4,
      dayNames.length > 3 ? dayNames[3] : '--',
    );
    await HomeWidget.saveWidgetData<String>(
      _kDayName5,
      dayNames.length > 4 ? dayNames[4] : '--',
    );
    await HomeWidget.saveWidgetData<String>(
      _kDayName6,
      dayNames.length > 5 ? dayNames[5] : '--',
    );
    await HomeWidget.saveWidgetData<String>(
      _kDayName7,
      dayNames.length > 6 ? dayNames[6] : '--',
    );
    await HomeWidget.saveWidgetData<String>(
      _kDayTemp1,
      dayTemps.isNotEmpty ? dayTemps[0] : '-- / --',
    );
    await HomeWidget.saveWidgetData<String>(
      _kDayTemp2,
      dayTemps.length > 1 ? dayTemps[1] : '-- / --',
    );
    await HomeWidget.saveWidgetData<String>(
      _kDayTemp3,
      dayTemps.length > 2 ? dayTemps[2] : '-- / --',
    );
    await HomeWidget.saveWidgetData<String>(
      _kDayTemp4,
      dayTemps.length > 3 ? dayTemps[3] : '-- / --',
    );
    await HomeWidget.saveWidgetData<String>(
      _kDayTemp5,
      dayTemps.length > 4 ? dayTemps[4] : '-- / --',
    );
    await HomeWidget.saveWidgetData<String>(
      _kDayTemp6,
      dayTemps.length > 5 ? dayTemps[5] : '-- / --',
    );
    await HomeWidget.saveWidgetData<String>(
      _kDayTemp7,
      dayTemps.length > 6 ? dayTemps[6] : '-- / --',
    );
    await HomeWidget.saveWidgetData<String>(
      _kDayIcon1,
      dayIcons.isNotEmpty ? dayIcons[0] : 'partly',
    );
    await HomeWidget.saveWidgetData<String>(
      _kDayIcon2,
      dayIcons.length > 1 ? dayIcons[1] : 'partly',
    );
    await HomeWidget.saveWidgetData<String>(
      _kDayIcon3,
      dayIcons.length > 2 ? dayIcons[2] : 'partly',
    );
    await HomeWidget.saveWidgetData<String>(
      _kDayIcon4,
      dayIcons.length > 3 ? dayIcons[3] : 'partly',
    );
    await HomeWidget.saveWidgetData<String>(
      _kDayIcon5,
      dayIcons.length > 4 ? dayIcons[4] : 'partly',
    );
    await HomeWidget.saveWidgetData<String>(
      _kDayIcon6,
      dayIcons.length > 5 ? dayIcons[5] : 'partly',
    );
    await HomeWidget.saveWidgetData<String>(
      _kDayIcon7,
      dayIcons.length > 6 ? dayIcons[6] : 'partly',
    );
    await HomeWidget.saveWidgetData<String>(
      _kConditionGlyph,
      _glyphForCondition(condition),
    );
    await HomeWidget.saveWidgetData<String>(
      _kUpdatedAt,
      DateTime.now().toLocal().toIso8601String(),
    );

    await _pushUpdate();
  }

  static Future<void> refreshFromBackground() async {
    if (kIsWeb) {
      return;
    }

    final location = await HomeWidget.getWidgetData<String>(_kLocationQuery);

    if (location == null || location.isEmpty) {
      await HomeWidget.saveWidgetData<String>(
        _kConditionText,
        'Open app to set location',
      );
      await HomeWidget.saveWidgetData<String>(_kTemperature, '--');
      await HomeWidget.saveWidgetData<String>(_kHighLow, '-- / --');
      await HomeWidget.saveWidgetData<String>(_kConditionGlyph, '...');
      await HomeWidget.saveWidgetData<String>(_kFeelsLike, '--');
      await HomeWidget.saveWidgetData<String>(_kHumidity, '--');
      await HomeWidget.saveWidgetData<String>(_kWind, '--');
      await HomeWidget.saveWidgetData<String>(_kAqi, '--');
      await HomeWidget.saveWidgetData<String>('wf_hourly_source_transition', '');
      await HomeWidget.saveWidgetData<String>('wf_daily_source_transition', '');
      for (int index = 1; index <= 24; index++) {
        await HomeWidget.saveWidgetData<String>('wf_hour_$index', '--');
        await HomeWidget.saveWidgetData<String>(
          'wf_hour_icon_$index',
          'partly',
        );
        await HomeWidget.saveWidgetData<String>('wf_hour_temp_$index', '--');
        await HomeWidget.saveWidgetData<String>('wf_hour_condition_$index', '');
      }
      await HomeWidget.saveWidgetData<String>(_kDayName1, '--');
      await HomeWidget.saveWidgetData<String>(_kDayName2, '--');
      await HomeWidget.saveWidgetData<String>(_kDayName3, '--');
      await HomeWidget.saveWidgetData<String>(_kDayTemp1, '-- / --');
      await HomeWidget.saveWidgetData<String>(_kDayTemp2, '-- / --');
      await HomeWidget.saveWidgetData<String>(_kDayTemp3, '-- / --');
      await HomeWidget.saveWidgetData<String>(_kDayIcon1, 'partly');
      await HomeWidget.saveWidgetData<String>(_kDayIcon2, 'partly');
      await HomeWidget.saveWidgetData<String>(_kDayIcon3, 'partly');
      await _pushUpdate();
      return;
    }

    final useFahrenheit = await PreferencesService.loadUseFahrenheit();
    final weatherService = WeatherService();
    final weatherData = await weatherService.fetchWeather(location);
    final forecastData = await weatherService.fetchForecast(location);

    GlobalData.useFahrenheit = useFahrenheit;

    await PreferencesService.saveLastLocationQuery(location);
    await WeatherCacheService.saveSnapshot(
      locationQuery: location,
      weatherData: weatherData,
      forecastData: forecastData,
    );

    await storeAndRefresh(
      weatherData: weatherData,
      useFahrenheit: useFahrenheit,
    );
  }

  static Future<void> _pushUpdate() async {
    if (kIsWeb) {
      return;
    }

    await HomeWidget.updateWidget(
      androidName: 'WeatherFastSmallWidgetProvider',
    );
    await HomeWidget.updateWidget(
      androidName: 'WeatherFastMediumWidgetProvider',
    );
    await HomeWidget.updateWidget(
      androidName: 'WeatherFastLargeWidgetProvider',
    );
  }

  static Future<void> refreshWidgets() async {
    if (kIsWeb) {
      return;
    }

    await _pushUpdate();
  }

  static String _glyphForCondition(String condition) {
    final lower = condition.toLowerCase();
    if (lower.contains('rain') ||
        lower.contains('drizzle') ||
        lower.contains('shower')) {
      return 'rain';
    }
    if (lower.contains('snow') ||
        lower.contains('sleet') ||
        lower.contains('ice')) {
      return 'snow';
    }
    if (lower.contains('storm') || lower.contains('thunder')) {
      return 'storm';
    }
    if (lower.contains('cloud') || lower.contains('overcast')) {
      return 'cloud';
    }
    if (lower.contains('fog') ||
        lower.contains('mist') ||
        lower.contains('haze')) {
      return 'fog';
    }
    return 'clear';
  }

  static String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '--';
    }
  }

  static String _formatHourLabel(DateTime dateTime) {
    final hour = dateTime.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12 $period';
  }
}
