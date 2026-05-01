import 'dart:convert';
import 'package:http/http.dart' as http;
import 'weather_service_sg.dart';

class WeatherService {
  final String _geoUrl = 'https://geocoding-api.open-meteo.com/v1/search';
  final String _weatherUrl = 'https://api.open-meteo.com/v1/forecast';
  final String _airQualityUrl =
      'https://air-quality-api.open-meteo.com/v1/air-quality';

  /// Fetch current weather and forecast for a location
  /// Returns data compatible with the app's existing UI expectations
  Future<Map<String, dynamic>> fetchWeather(String location) async {
    try {
      // First, get coordinates for the location
      final coords = await _getLocationCoordinates(location);
      if (coords == null) {
        throw Exception('Location not found');
      }

      // If location is in Singapore, delegate to Singapore service
      try {
        final lat = (coords['lat'] as num?)?.toDouble() ?? 0.0;
        final lon = (coords['lon'] as num?)?.toDouble() ?? 0.0;
        final country = (coords['country'] ?? '').toString().toLowerCase();
        
        final isSingaporeCoords = lat >= 1.15 && lat <= 1.50 && lon >= 103.55 && lon <= 104.15;
        
        if (country.contains('singapore') || isSingaporeCoords) {
          final sg = SingaporeWeatherService();
          return await sg.fetchWeatherFromCoords(lat, lon);
        }
      } catch (_) {}

      // Fetch weather data for those coordinates
      final weatherData = await _fetchWeatherData(coords['lat'], coords['lon']);
      final airQuality = await _fetchAirQualityData(
        coords['lat'],
        coords['lon'],
      );

      // Get current time in the location's timezone
      final currentTime = weatherData['current']['time'];
      final hourly = weatherData['hourly'];

      final List<Map<String, dynamic>> nextHours = [];
      final List<Map<String, dynamic>> nextDays = [];
      double? todayHighC;
      double? todayLowC;
      try {
        final hourlyTimes =
            (hourly['time'] as List?)?.map((e) => e.toString()).toList() ??
            const [];
        final hourlyTemps =
            (hourly['temperature_2m'] as List?)?.toList() ?? const [];
        final hourlyCodes =
            (hourly['weather_code'] as List?)?.toList() ?? const [];
        final currentDateTime = DateTime.tryParse(
          currentTime?.toString() ?? '',
        );

        for (int i = 0; i < hourlyTimes.length; i++) {
          if (i >= hourlyTemps.length || i >= hourlyCodes.length) {
            break;
          }

          final slotTime = DateTime.tryParse(hourlyTimes[i]);
          if (slotTime == null) {
            continue;
          }

          if (currentDateTime != null && !slotTime.isAfter(currentDateTime)) {
            continue;
          }

          final tempC = (hourlyTemps[i] as num).toDouble();
          final weatherCode = (hourlyCodes[i] as num).toInt();

          nextHours.add({
            'time': hourlyTimes[i],
            'temp_c': tempC,
            'temp_f': (tempC * 9 / 5) + 32,
            'condition': {'text': _getWeatherDescription(weatherCode)},
            'glyph': _getWeatherGlyph(weatherCode),
          });

          if (nextHours.length >= 24) {
            break;
          }
        }
      } catch (_) {}

      try {
        final daily = weatherData['daily'];
        final dayDates =
            (daily['time'] as List?)?.map((e) => e.toString()).toList() ??
            const [];
        final dayMax =
            (daily['temperature_2m_max'] as List?)?.toList() ?? const [];
        final dayMin =
            (daily['temperature_2m_min'] as List?)?.toList() ?? const [];
        final dayCodes = (daily['weather_code'] as List?)?.toList() ?? const [];

        if (dayMax.isNotEmpty && dayMin.isNotEmpty) {
          todayHighC = (dayMax[0] as num).toDouble();
          todayLowC = (dayMin[0] as num).toDouble();
        }

        for (int i = 1; i < dayDates.length; i++) {
          if (i >= dayMax.length ||
              i >= dayMin.length ||
              i >= dayCodes.length) {
            break;
          }

          final code = (dayCodes[i] as num).toInt();
          final maxC = (dayMax[i] as num).toDouble();
          final minC = (dayMin[i] as num).toDouble();
          nextDays.add({
            'date': dayDates[i],
            'max_c': maxC,
            'max_f': (maxC * 9 / 5) + 32,
            'min_c': minC,
            'min_f': (minC * 9 / 5) + 32,
            'condition': {'text': _getWeatherDescription(code)},
            'glyph': _getWeatherGlyph(code),
          });

          if (nextDays.length >= 7) {
            break;
          }
        }
      } catch (_) {}

      // Transform to match expected format
      return {
        'location': {
          'name': coords['name'] ?? 'Unknown',
          'region': coords['region'] ?? '',
          'country': coords['country'] ?? '',
          'lat': coords['lat'],
          'lon': coords['lon'],
          'tz_id': weatherData['timezone'] ?? 'UTC',
          'localtime': currentTime ?? '',
        },
        'current': {
          'temp_c': (weatherData['current']['temperature_2m'] as num)
              .toDouble(),
          'temp_f':
              ((weatherData['current']['temperature_2m'] as num).toDouble() *
                  9 /
                  5) +
              32,
          'feelslike_c': (weatherData['current']['apparent_temperature'] as num)
              .toDouble(),
          'feelslike_f':
              ((weatherData['current']['apparent_temperature'] as num)
                      .toDouble() *
                  9 /
                  5) +
              32,
          'condition': {
            'text': _getWeatherDescription(
              (weatherData['current']['weather_code'] as num).toInt(),
            ),
            'icon': '//cdn.weatherapi.com/weather/64x64/day/116.png',
          },
          'humidity': (weatherData['current']['relative_humidity_2m'] as num)
              .toInt(),
          'wind_kph': (weatherData['current']['wind_speed_10m'] as num)
              .toDouble(),
          'wind_degree': (weatherData['current']['wind_direction_10m'] as num)
              .toInt(),
          'wind_dir': _getWindDirection(
            (weatherData['current']['wind_direction_10m'] as num).toInt(),
          ),
          'pressure_mb': (weatherData['current']['pressure_msl'] as num)
              .toDouble(),
          'precip_mm': 0.0,
          'vis_km': (() {
            // Prefer current visibility if provided (meters -> km)
            if (weatherData['current']?.containsKey('visibility') == true) {
              final v = weatherData['current']['visibility'];
              if (v is num) return v.toDouble() / 1000.0;
            }
            // Fallback to hourly visibility nearest to current time
            try {
              final hourly = weatherData['hourly'];
              final times =
                  (hourly['time'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  const [];
              final visList =
                  (hourly['visibility'] as List?)?.toList() ?? const [];
              if (times.isEmpty || visList.isEmpty) return 10.0;

              final currentStr = weatherData['current']['time']?.toString();
              if (currentStr == null) return 10.0;
              final current = DateTime.tryParse(currentStr);
              if (current == null) return 10.0;

              // Hourly stamps are at HH:00; align by flooring minutes
              final aligned = DateTime(
                current.year,
                current.month,
                current.day,
                current.hour,
              );
              final alignedStr =
                  '${aligned.toIso8601String().substring(0, 13)}:00';

              // Find exact hour match, else nearest
              int idx = times.indexWhere((t) => t.startsWith(alignedStr));
              if (idx < 0) {
                // Nearest by absolute difference
                Duration best = const Duration(days: 365);
                int bestIdx = -1;
                for (int i = 0; i < times.length; i++) {
                  final dt = DateTime.tryParse(times[i]);
                  if (dt == null) continue;
                  final diff = (dt.difference(current)).abs();
                  if (diff < best) {
                    best = diff;
                    bestIdx = i;
                  }
                }
                idx = bestIdx;
              }

              if (idx >= 0 && idx < visList.length) {
                final v = visList[idx];
                if (v is num) return v.toDouble() / 1000.0;
              }
            } catch (_) {}
            // Sensible final fallback
            return 10.0;
          })(),
          'aqi': airQuality['us_aqi'],
          'air_quality_text': _getAQIDescription(airQuality['us_aqi']),
        },
        'widget_today_high_c': todayHighC,
        'widget_today_high_f': todayHighC == null
            ? null
            : (todayHighC * 9 / 5) + 32,
        'widget_today_low_c': todayLowC,
        'widget_today_low_f': todayLowC == null
            ? null
            : (todayLowC * 9 / 5) + 32,
        'widget_next_hours': nextHours,
        'widget_next_days': nextDays,
      };
    } catch (e) {
      throw Exception('Failed to load weather data: $e');
    }
  }

  /// Fetch 14-day forecast for a location
  Future<Map<String, dynamic>> fetchForecast(String location) async {
    try {
      final coords = await _getLocationCoordinates(location);
      if (coords == null) {
        throw Exception('Location not found');
      }

      // If Singapore, use Singapore service to construct forecast
      try {
        final lat = (coords['lat'] as num?)?.toDouble() ?? 0.0;
        final lon = (coords['lon'] as num?)?.toDouble() ?? 0.0;
        final country = (coords['country'] ?? '').toString().toLowerCase();
        
        final isSingaporeCoords = lat >= 1.15 && lat <= 1.50 && lon >= 103.55 && lon <= 104.15;

        if (country.contains('singapore') || isSingaporeCoords) {
          final sg = SingaporeWeatherService();
          final sgData = await sg.fetchWeatherFromCoords(lat, lon);
          // Map SG widget_next_days to forecastday expected shape
          final List<dynamic> forecastDays = [];
          final days = (sgData['widget_next_days'] as List?) ?? const [];
          final hourlyData = (sgData['widget_next_hours'] as List?) ?? const [];

          for (int i = 0; i < days.length; i++) {
            final d = days[i];
            final dateStr = d['date'] ?? '';
            final dayDate = DateTime.tryParse(dateStr);
            
            // Group hourly data for this day
            final List<dynamic> dayHourly = [];
            for (final h in hourlyData) {
              final hTimeStr = h['time']?.toString() ?? '';
              final hTime = DateTime.tryParse(hTimeStr);
              
              bool matches = false;
              if (hTimeStr.startsWith(dateStr)) {
                matches = true;
              } else if (dayDate != null && hTime != null) {
                matches = hTime.year == dayDate.year &&
                          hTime.month == dayDate.month &&
                          hTime.day == dayDate.day;
              }

              if (matches) {
                dayHourly.add({
                  'time': h['time'],
                  'display_time': h['display_time'],
                  'temp_c': h['temp_c'],
                  'temp_f': h['temp_f'],
                  'condition': h['condition'],
                  'chance_of_rain': h['chance_of_rain'] ?? 0,
                  'chance_of_snow': 0,
                  'source': h['source'] ?? 'nea',
                });
              }
            }

            forecastDays.add({
              'date': dateStr,
              'day': {
                'maxtemp_c': d['max_c'],
                'maxtemp_f': d['max_f'],
                'mintemp_c': d['min_c'],
                'mintemp_f': d['min_f'],
                'condition': d['condition'] ?? {},
                'daily_chance_of_rain': d['chance_of_rain'] ?? 0,
                'wind': d['wind'] ?? {},
                'humidity': d['humidity'] ?? {},
              },
              'hour': dayHourly,
              'source': d['source'] ?? 'nea',
            });
          }

          return {
            'source': 'nea',
            'location': sgData['location'],
            'current': sgData['current'],
            'forecast': {'forecastday': forecastDays},
          };
        }
      } catch (_) {}

      final weatherData = await _fetchWeatherData(coords['lat'], coords['lon']);
      final airQuality = await _fetchAirQualityData(
        coords['lat'],
        coords['lon'],
      );

      // Transform daily forecast to match expected format
      final List<dynamic> forecastDays = [];
      final daily = weatherData['daily'];
      final hourly = weatherData['hourly'];

      // Safely extract lists with proper type handling
      final dates = daily['time'] as List;
      final weatherCodes = daily['weather_code'] as List;
      final maxTemps = daily['temperature_2m_max'] as List;
      final minTemps = daily['temperature_2m_min'] as List;
      final precipProb = daily['precipitation_probability_max'] as List;

      // Extract hourly data
      final hourlyTimes = hourly['time'] as List;
      final hourlyTemps = hourly['temperature_2m'] as List;
      final hourlyFeelsLike = hourly['apparent_temperature'] as List;
      final hourlyWeatherCodes = hourly['weather_code'] as List;
      final hourlyPrecipProb = hourly['precipitation_probability'] as List;

        for (int i = 0; i < dates.length && i < 14; i++) {
          final maxTemp = (maxTemps[i] as num).toDouble();
          final minTemp = (minTemps[i] as num).toDouble();
          final weatherCode = (weatherCodes[i] as num).toInt();
          final precip = (precipProb[i] as num).toInt();

          // Get hourly data for this day
          final dayDate = dates[i].toString();
          final List<dynamic> hourlyDataForDay = [];
          
          double? dayWindLow;
          double? dayWindHigh;
          int? dayRhLow;
          int? dayRhHigh;

          // Extract hourly values for wind and humidity to find ranges
          final hourlyWind = hourly['wind_speed_10m'] as List?;
          final hourlyRh = hourly['relative_humidity_2m'] as List?;

          for (int h = 0; h < hourlyTimes.length; h++) {
            final hourTimeStr = hourlyTimes[h].toString();
            if (hourTimeStr.startsWith(dayDate)) {
              final tC = (hourlyTemps[h] as num).toDouble();
              hourlyDataForDay.add({
                'time': hourTimeStr,
                'temp_c': tC,
                'temp_f': (tC * 9 / 5) + 32,
                'feelslike_c': (hourlyFeelsLike[h] as num).toDouble(),
                'feelslike_f':
                    ((hourlyFeelsLike[h] as num).toDouble() * 9 / 5) + 32,
                'chance_of_rain': (hourlyPrecipProb[h] as num?)?.toInt() ?? 0,
                'chance_of_snow': 0,
                'condition': {
                  'text': _getWeatherDescription(
                    (hourlyWeatherCodes[h] as num).toInt(),
                  ),
                  'icon': '//cdn.weatherapi.com/weather/64x64/day/116.png',
                },
              });

              if (hourlyWind != null && h < hourlyWind.length) {
                final w = (hourlyWind[h] as num).toDouble();
                if (dayWindLow == null || w < dayWindLow) dayWindLow = w;
                if (dayWindHigh == null || w > dayWindHigh) dayWindHigh = w;
              }
              if (hourlyRh != null && h < hourlyRh.length) {
                final r = (hourlyRh[h] as num).toInt();
                if (dayRhLow == null || r < dayRhLow) dayRhLow = r;
                if (dayRhHigh == null || r > dayRhHigh) dayRhHigh = r;
              }
            }
          }

          forecastDays.add({
            'date': dayDate,
            'day': {
              'maxtemp_c': maxTemp,
              'maxtemp_f': (maxTemp * 9 / 5) + 32,
              'mintemp_c': minTemp,
              'mintemp_f': (minTemp * 9 / 5) + 32,
              'condition': {
                'text': _getWeatherDescription(weatherCode),
                'icon': '//cdn.weatherapi.com/weather/64x64/day/116.png',
              },
              'daily_chance_of_rain': precip,
              'wind': {
                'low_kph': dayWindLow ?? 0.0,
                'high_kph': dayWindHigh ?? 0.0,
              },
              'humidity': {
                'low': dayRhLow ?? 0,
                'high': dayRhHigh ?? 0,
              },
            },
            'astro': {
              'moon_phase': 'New Moon',
              'sunrise': '06:00 AM',
              'sunset': '06:00 PM',
            },
            'hour': hourlyDataForDay,
          });
        }

      return {
        'location': {
          'name': coords['name'] ?? 'Unknown',
          'region': coords['region'] ?? '',
          'country': coords['country'] ?? '',
          'lat': coords['lat'],
          'lon': coords['lon'],
          'tz_id': weatherData['timezone'] ?? 'UTC',
        },
        'current': {
          'temp_c': (weatherData['current']['temperature_2m'] as num)
              .toDouble(),
          'temp_f':
              ((weatherData['current']['temperature_2m'] as num).toDouble() *
                  9 /
                  5) +
              32,
          'feelslike_c': (weatherData['current']['apparent_temperature'] as num)
              .toDouble(),
          'feelslike_f':
              ((weatherData['current']['apparent_temperature'] as num)
                      .toDouble() *
                  9 /
                  5) +
              32,
          'condition': {
            'text': _getWeatherDescription(
              (weatherData['current']['weather_code'] as num).toInt(),
            ),
            'icon': '//cdn.weatherapi.com/weather/64x64/day/116.png',
          },
          'humidity': (weatherData['current']['relative_humidity_2m'] as num)
              .toInt(),
          'wind_kph': (weatherData['current']['wind_speed_10m'] as num)
              .toDouble(),
          'wind_degree': (weatherData['current']['wind_direction_10m'] as num)
              .toInt(),
          'wind_dir': _getWindDirection(
            (weatherData['current']['wind_direction_10m'] as num).toInt(),
          ),
          'pressure_mb': (weatherData['current']['pressure_msl'] as num)
              .toDouble(),
          'precip_mm': 0.0,
          'vis_km': (() {
            if (weatherData['current']?.containsKey('visibility') == true) {
              final v = weatherData['current']['visibility'];
              if (v is num) return v.toDouble() / 1000.0;
            }
            try {
              final hourly = weatherData['hourly'];
              final times =
                  (hourly['time'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  const [];
              final visList =
                  (hourly['visibility'] as List?)?.toList() ?? const [];
              if (times.isEmpty || visList.isEmpty) return 10.0;

              final currentStr = weatherData['current']['time']?.toString();
              if (currentStr == null) return 10.0;
              final current = DateTime.tryParse(currentStr);
              if (current == null) return 10.0;

              final aligned = DateTime(
                current.year,
                current.month,
                current.day,
                current.hour,
              );
              final alignedStr =
                  '${aligned.toIso8601String().substring(0, 13)}:00';

              int idx = times.indexWhere((t) => t.startsWith(alignedStr));
              if (idx < 0) {
                Duration best = const Duration(days: 365);
                int bestIdx = -1;
                for (int i = 0; i < times.length; i++) {
                  final dt = DateTime.tryParse(times[i]);
                  if (dt == null) continue;
                  final diff = (dt.difference(current)).abs();
                  if (diff < best) {
                    best = diff;
                    bestIdx = i;
                  }
                }
                idx = bestIdx;
              }

              if (idx >= 0 && idx < visList.length) {
                final v = visList[idx];
                if (v is num) return v.toDouble() / 1000.0;
              }
            } catch (_) {}
            return 10.0;
          })(),
          'aqi': airQuality['us_aqi'],
          'air_quality_text': _getAQIDescription(airQuality['us_aqi']),
        },
        'forecast': {'forecastday': forecastDays},
      };
    } catch (e) {
      throw Exception('Failed to load forecast data: $e');
    }
  }

  /// Search for locations by name
  Future<List<String>> searchLocations(String query) async {
    if (query.isEmpty) return [];

    try {
      final url = Uri.parse(
        '$_geoUrl?name=$query&count=10&language=en&format=json',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] == null || (data['results'] as List).isEmpty) {
          return [];
        }
        return (data['results'] as List)
            .map<String>((item) => '${item['name']}, ${item['country']}')
            .toList();
      } else {
        throw Exception('Failed to fetch location suggestions');
      }
    } catch (e) {
      throw Exception('Failed to search locations: $e');
    }
  }

  /// Get coordinates for a location name or parse lat,lon coordinates
  Future<Map<String, dynamic>?> _getLocationCoordinates(String location) async {
    try {
      // Check if the location is in lat,lon format (e.g., "37.7749,-122.4194")
      if (location.contains(',')) {
        final parts = location.split(',');
        if (parts.length == 2) {
          final lat = double.tryParse(parts[0].trim());
          final lon = double.tryParse(parts[1].trim());
          if (lat != null && lon != null) {
            // Use BigDataCloud free reverse geocoding API (no key required)
            try {
              final reverseGeoUrl = Uri.parse(
                'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=en',
              );
              final reverseResponse = await http.get(reverseGeoUrl);

              if (reverseResponse.statusCode == 200) {
                final reverseData = jsonDecode(reverseResponse.body);
                final city =
                    reverseData['city'] ?? reverseData['locality'] ?? 'Unknown';
                final country = reverseData['countryName'] ?? '';
                final region = reverseData['principalSubdivision'] ?? '';

                return {
                  'name': city,
                  'region': region,
                  'country': country,
                  'lat': lat,
                  'lon': lon,
                };
              }
            } catch (e) {
              // Fallback if reverse geocoding fails
            }

            // Fallback to generic name if reverse geocoding fails
            return {
              'name': 'Location ($lat, $lon)',
              'region': '',
              'country': '',
              'lat': lat,
              'lon': lon,
            };
          }
        }
      }

      // Otherwise, search by location name
      final url = Uri.parse(
        '$_geoUrl?name=$location&count=1&language=en&format=json',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] == null || (data['results'] as List).isEmpty) {
          return null;
        }
        final result = data['results'][0];
        return {
          'name': result['name'] ?? 'Unknown',
          'region': result['admin1']?.toString() ?? '',
          'country': result['country']?.toString() ?? '',
          'lat': (result['latitude'] as num).toDouble(),
          'lon': (result['longitude'] as num).toDouble(),
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetch weather data from Open-Meteo API
  Future<Map<String, dynamic>> _fetchWeatherData(double lat, double lon) async {
    final url = Uri.parse(
      '$_weatherUrl?latitude=$lat&longitude=$lon'
      '&current=temperature_2m,apparent_temperature,weather_code,relative_humidity_2m,wind_speed_10m,wind_direction_10m,pressure_msl,visibility'
      '&hourly=temperature_2m,apparent_temperature,weather_code,visibility,precipitation_probability,wind_speed_10m,relative_humidity_2m'
      '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max'
      '&timezone=auto'
      '&forecast_days=14',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to fetch weather data: ${response.statusCode} ${response.body}',
      );
    }
  }

  /// Fetch air quality data from Open-Meteo Air Quality API
  Future<Map<String, dynamic>> _fetchAirQualityData(
    double lat,
    double lon,
  ) async {
    try {
      final url = Uri.parse(
        '$_airQualityUrl?latitude=$lat&longitude=$lon'
        '&current=us_aqi,pm10,pm2_5'
        '&timezone=auto',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current'] ?? {};
        return {
          'us_aqi': (current['us_aqi'] as num?)?.toInt() ?? 0,
          'pm10': (current['pm10'] as num?)?.toDouble() ?? 0.0,
          'pm2_5': (current['pm2_5'] as num?)?.toDouble() ?? 0.0,
        };
      } else {
        // Return default values if AQI fetch fails
        return {'us_aqi': 0, 'pm10': 0.0, 'pm2_5': 0.0};
      }
    } catch (e) {
      // Return default values on error
      return {'us_aqi': 0, 'pm10': 0.0, 'pm2_5': 0.0};
    }
  }

  /// Get AQI description based on US AQI scale
  String _getAQIDescription(int aqi) {
    if (aqi == 0) return 'Unknown';
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy for Sensitive';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi <= 300) return 'Very Unhealthy';
    return 'Hazardous';
  }

  /// Convert WMO weather code to human-readable description
  String _getWeatherDescription(int code) {
    // WMO Weather interpretation codes
    if (code == 0) return 'Clear sky';
    if (code == 1 || code == 2) return 'Mostly clear';
    if (code == 3) return 'Overcast';
    if (code == 45 || code == 48) return 'Foggy';
    if (code == 51 || code == 53 || code == 55) return 'Drizzle';
    if (code == 61 || code == 63 || code == 65) return 'Rain';
    if (code == 71 || code == 73 || code == 75) return 'Snow';
    if (code == 77) return 'Snow grains';
    if (code == 80 || code == 81 || code == 82) return 'Rain showers';
    if (code == 85 || code == 86) return 'Snow showers';
    if (code == 95 || code == 96 || code == 99) return 'Thunderstorm';
    return 'Unknown';
  }

  String _getWeatherGlyph(int code) {
    if (code == 0) return 'clear';
    if (code == 1 || code == 2) return 'partly';
    if (code == 3) return 'cloud';
    if (code == 45 || code == 48) return 'fog';
    if (code == 51 || code == 53 || code == 55) return 'rain';
    if (code == 61 || code == 63 || code == 65) return 'rain';
    if (code == 71 || code == 73 || code == 75) return 'snow';
    if (code == 77) return 'snow';
    if (code == 80 || code == 81 || code == 82) return 'rain';
    if (code == 85 || code == 86) return 'snow';
    if (code == 95 || code == 96 || code == 99) return 'storm';
    return 'partly';
  }

  /// Convert wind degree to cardinal direction
  String _getWindDirection(int degree) {
    if (degree >= 337.5 || degree < 22.5) return 'N';
    if (degree >= 22.5 && degree < 67.5) return 'NE';
    if (degree >= 67.5 && degree < 112.5) return 'E';
    if (degree >= 112.5 && degree < 157.5) return 'SE';
    if (degree >= 157.5 && degree < 202.5) return 'S';
    if (degree >= 202.5 && degree < 247.5) return 'SW';
    if (degree >= 247.5 && degree < 292.5) return 'W';
    if (degree >= 292.5 && degree < 337.5) return 'NW';
    return 'N';
  }
}
