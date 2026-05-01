import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class SingaporeWeatherService {
  final String _base = 'https://api.weatherfast.aadish.dev';

  Future<Map<String, dynamic>> fetchWeatherFromCoords(double lat, double lon) async {
    final current = await fetchCurrent(lat, lon);
    final hourlyNea = await fetchHourly(lat, lon);
    final dailyNea = await fetchDaily(lat, lon);
    final psi = await fetchPSI(lat, lon);

    // Fetch Open-Meteo for granular daily data and hourly continuation
    List<Map<String, dynamic>> hourlyOm = [];
    List<Map<String, dynamic>> dailyOm = [];
    try {
      final omData = await _fetchOpenMeteo(lat, lon);
      hourlyOm = omData['hourly'] ?? [];
      dailyOm = omData['daily'] ?? [];
    } catch (_) {}

    // Construct "Today" from current or first hourly period if missing in daily list
    // The 24-hour forecast usually covers "Today".
    List<Map<String, dynamic>> dailyMerged = [];
    final todayStr = current['localtime']?.toString().split('T')[0] ?? 
                    DateTime.now().toUtc().add(const Duration(hours: 8)).toIso8601String().split('T')[0];
    
    bool hasToday = dailyNea.any((d) => d['date'] == todayStr);
    if (!hasToday) {
      // Create a Day 1 summary
      dailyMerged.add({
        'date': todayStr,
        'max_c': (current['temp_c'] as num).toDouble(),
        'min_c': (current['temp_c'] as num).toDouble() - 5, // Estimated
        'condition': current['condition'],
        'glyph': _mapConditionToGlyph(current['condition']['text']),
        'wind': {'low_kph': 5.0, 'high_kph': 15.0},
        'humidity': {'low': 60, 'high': 95},
        'chance_of_rain': hourlyNea.isNotEmpty ? hourlyNea[0]['chance_of_rain'] : 0,
        'source': 'nea',
      });
    }
    dailyMerged.addAll(dailyNea);

    // Merge Hourly: Use NEA periods first, then continue with OM hourly
    final lastNeaEndStr = hourlyNea.isEmpty ? '' : hourlyNea.last['end'];
    final lastNeaEnd = DateTime.tryParse(lastNeaEndStr ?? '') ?? 
                      DateTime.now().toUtc().add(const Duration(hours: 8));

    final hourly = [
      ...hourlyNea,
      ...hourlyOm.where((h) {
        final t = DateTime.tryParse(h['time']?.toString() ?? '');
        return t != null && t.isAfter(lastNeaEnd);
      }),
    ];

    // For daily extension, NEA gives 4-5 days. OM gives more.
    final lastNeaDayStr = dailyMerged.isEmpty ? todayStr : dailyMerged.last['date'];
    final lastNeaDay = DateTime.tryParse(lastNeaDayStr) ?? DateTime.now();
    
    final daily = [
      ...dailyMerged,
      ...dailyOm.where((d) {
        final t = DateTime.tryParse(d['date']);
        return t != null && t.isAfter(lastNeaDay);
      }),
    ];

    final currentData = {
      ...current,
      'feelslike_c': current['temp_c'],
      'feelslike_f': current['temp_f'],
      'wind_degree': 0,
      'wind_dir': 'N',
      'pressure_mb': 1010.0,
      'precip_mm': 0.0,
      'vis_km': 10.0,
      if (psi != null) ...psi,
    };

    final regionalOutlook = await fetchRegionalOutlook();

    return {
      'location': {
        'name': current['area_name'] ?? 'Singapore',
        'region': '',
        'country': 'Singapore',
        'lat': lat,
        'lon': lon,
        'tz_id': 'Asia/Singapore',
        'localtime': current['localtime'],
      },
      'current': currentData,
      'widget_next_hours': hourly,
      'widget_next_days': daily,
      'sg_regions': regionalOutlook.isNotEmpty ? regionalOutlook : null,
      'sg_period_ranges': regionalOutlook,
      if (dailyMerged.isNotEmpty) 'widget_today_high_c': dailyMerged[0]['max_c'],
      if (dailyMerged.isNotEmpty) 'widget_today_high_f': (dailyMerged[0]['max_c'] * 9 / 5) + 32,
      if (dailyMerged.isNotEmpty) 'widget_today_low_c': dailyMerged[0]['min_c'],
      if (dailyMerged.isNotEmpty) 'widget_today_low_f': (dailyMerged[0]['min_c'] * 9 / 5) + 32,
    };
    }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchOpenMeteo(double lat, double lon) async {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
      '&hourly=temperature_2m,weather_code,precipitation_probability'
      '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max'
      '&timezone=auto',
    );
    final res = await http.get(url);
    if (res.statusCode != 200) return {};

    final data = jsonDecode(res.body);
    final List<Map<String, dynamic>> hourly = [];
    final List<Map<String, dynamic>> daily = [];

    final hData = data['hourly'] ?? {};
    final hTimes = hData['time'] as List? ?? [];
    final hTemps = hData['temperature_2m'] as List? ?? [];
    final hCodes = hData['weather_code'] as List? ?? [];
    final hPrecip = hData['precipitation_probability'] as List? ?? [];

    for (int i = 0; i < hTimes.length; i++) {
      final tC = (hTemps[i] as num).toDouble();
      final code = (hCodes[i] as num).toInt();
      hourly.add({
        'time': hTimes[i],
        'temp_c': tC,
        'temp_f': (tC * 9 / 5) + 32,
        'condition': {'text': _getWmoDescription(code)},
        'glyph': _getWmoGlyph(code),
        'chance_of_rain': (hPrecip[i] as num).toInt(),
        'source': 'open-meteo',
      });
    }

    final dData = data['daily'] ?? {};
    final dTimes = dData['time'] as List? ?? [];
    final dMax = dData['temperature_2m_max'] as List? ?? [];
    final dMin = dData['temperature_2m_min'] as List? ?? [];
    final dCodes = dData['weather_code'] as List? ?? [];
    final dPrecip = dData['precipitation_probability_max'] as List? ?? [];

    for (int i = 0; i < dTimes.length; i++) {
      final maxC = (dMax[i] as num).toDouble();
      final minC = (dMin[i] as num).toDouble();
      final code = (dCodes[i] as num).toInt();
      daily.add({
        'date': dTimes[i],
        'max_c': maxC,
        'max_f': (maxC * 9 / 5) + 32,
        'min_c': minC,
        'min_f': (minC * 9 / 5) + 32,
        'condition': {'text': _getWmoDescription(code)},
        'glyph': _getWmoGlyph(code),
        'chance_of_rain': (dPrecip[i] as num).toInt(),
        'source': 'open-meteo',
      });
    }

    return {'hourly': hourly, 'daily': daily};
  }

  String _getWmoDescription(int code) {
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

  String _getWmoGlyph(int code) {
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

  Future<Map<String, dynamic>> fetchCurrent(double lat, double lon) async {
    final airTempRes = await http.get(Uri.parse('$_base/api/sg/air-temperature'));
    final twoHourRes = await http.get(Uri.parse('$_base/api/sg/two-hour-forecast'));
    final rhRes = await http.get(Uri.parse('$_base/api/sg/relative-humidity'));
    final windRes = await http.get(Uri.parse('$_base/api/sg/wind-speed'));

    double temp = 0.0;
    String condition = 'Clear';
    int humidity = 0;
    double windKph = 0.0;
    String areaName = 'Singapore';

    if (airTempRes.statusCode == 200) {
      final data = jsonDecode(airTempRes.body);
      final nearest = _findNearestPointFromStations(lat, lon, data['data']?['stations']);
      if (nearest != null) {
        final sid = nearest['id'] ?? nearest['deviceId'];
        final readings = (data['data']?['readings'] as List?) ?? [];
        if (readings.isNotEmpty) {
          final found = (readings[0]['data'] as List?)?.firstWhere((d) => d['stationId'] == sid, orElse: () => null);
          if (found != null) temp = (found['value'] as num).toDouble();
        }
      }
    }

    if (twoHourRes.statusCode == 200) {
      final data = jsonDecode(twoHourRes.body);
      final areas = (data['data']?['area_metadata'] as List?) ?? [];
      final nearest = _findNearestPoint(lat, lon, areas, (a) => a['label_location']);
      if (nearest != null) {
        areaName = nearest['name'] ?? areaName;
        final forecasts = (data['data']?['items']?[0]?['forecasts'] as List?) ?? [];
        final fFound = forecasts.firstWhere((f) => f['area'] == areaName, orElse: () => null);
        if (fFound != null) condition = fFound['forecast'] ?? condition;
      }
    }

    if (rhRes.statusCode == 200) {
      final data = jsonDecode(rhRes.body);
      final nearest = _findNearestPointFromStations(lat, lon, data['data']?['stations']);
      if (nearest != null) {
        final sid = nearest['id'] ?? nearest['deviceId'];
        final readings = (data['data']?['readings'] as List?) ?? [];
        if (readings.isNotEmpty) {
          final found = (readings[0]['data'] as List?)?.firstWhere((d) => d['stationId'] == sid, orElse: () => null);
          if (found != null) humidity = (found['value'] as num).toInt();
        }
      }
    }

    if (windRes.statusCode == 200) {
      final data = jsonDecode(windRes.body);
      final nearest = _findNearestPointFromStations(lat, lon, data['data']?['stations']);
      if (nearest != null) {
        final sid = nearest['id'] ?? nearest['deviceId'];
        final readings = (data['data']?['readings'] as List?) ?? [];
        if (readings.isNotEmpty) {
          final found = (readings[0]['data'] as List?)?.firstWhere((d) => d['stationId'] == sid, orElse: () => null);
          if (found != null) windKph = (found['value'] as num).toDouble();
        }
      }
    }

    return {
      'temp_c': temp,
      'temp_f': (temp * 9 / 5) + 32,
      'condition': {'text': condition},
      'humidity': humidity,
      'wind_kph': windKph,
      'area_name': areaName,
      'localtime': DateTime.now().toUtc().add(const Duration(hours: 8)).toIso8601String(),
    };
  }

  Future<List<Map<String, dynamic>>> fetchHourly(double lat, double lon, {String? areaRegion}) async {
    final day24Res = await http.get(Uri.parse('$_base/api/sg/twenty-four-hr-forecast'));
    if (day24Res.statusCode != 200) return [];
    
    final day24 = jsonDecode(day24Res.body);
    final data = day24['data'] ?? {};
    final record = (data['records'] as List?)?.firstOrNull ?? (data['items'] as List?)?.firstOrNull;
    if (record == null) return [];

    final periods = (record['periods'] as List?) ?? [];
    final region = areaRegion?.toLowerCase() ?? 'central';

    // Also fetch Open-Meteo for precip chance
    List<int> precipChances = [];
    try {
      final omRes = await http.get(Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&hourly=precipitation_probability&timezone=auto&forecast_days=1',
      ));
      if (omRes.statusCode == 200) {
        final omData = jsonDecode(omRes.body);
        precipChances = (omData['hourly']?['precipitation_probability'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
      }
    } catch (_) {}

    final List<Map<String, dynamic>> results = [];
    for (final p in periods) {
      final timePeriod = p['timePeriod'] ?? p['time_period'] ?? {};
      final start = timePeriod['start'] ?? '';
      
      String cond = p['regions']?[region]?['text'] ?? p['regions']?['central']?['text'] ?? p['forecast'] ?? 'Clear';
      
      int maxPrecip = 0;
      final startDt = DateTime.tryParse(start);
      final endDt = DateTime.tryParse(timePeriod['end'] ?? '');
      if (precipChances.isNotEmpty && startDt != null && endDt != null) {
        for (int h = startDt.hour; h <= endDt.hour && h < precipChances.length; h++) {
          if (precipChances[h] > maxPrecip) maxPrecip = precipChances[h];
        }
      }

      results.add({
        'time': start,
        'display_time': timePeriod['text'] ?? timePeriod['label'] ?? '',
        'condition': {'text': cond},
        'glyph': _mapConditionToGlyph(cond),
        'chance_of_rain': maxPrecip,
        'temp_c': 0.0,
        'source': 'nea',
        'end': timePeriod['end'] ?? '',
      });
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> fetchDaily(double lat, double lon) async {
    final fourDayRes = await http.get(Uri.parse('$_base/api/sg/four-day-forecast'));
    if (fourDayRes.statusCode != 200) return [];
    
    final fourDay = jsonDecode(fourDayRes.body);
    final data = fourDay['data'] ?? {};
    final rec = (data['records'] as List?)?.firstOrNull ?? (data['items'] as List?)?.firstOrNull;
    if (rec == null) return [];

    final forecasts = (rec['forecasts'] as List?) ?? [];
    
    // Precip chance from Open-Meteo
    List<int> precipChances = [];
    try {
      final omRes = await http.get(Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&daily=precipitation_probability_max&timezone=auto&forecast_days=4',
      ));
      if (omRes.statusCode == 200) {
        final omData = jsonDecode(omRes.body);
        precipChances = (omData['daily']?['precipitation_probability_max'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
      }
    } catch (_) {}

    final List<Map<String, dynamic>> results = [];
    for (int i = 0; i < forecasts.length; i++) {
      final f = forecasts[i];
      final timestamp = f['timestamp'] ?? f['date'] ?? f['time'] ?? '';
      final dateStr = timestamp.toString().split('T')[0];
      final temp = f['temperature'] ?? {};
      final text = f['forecast']?['text'] ?? f['forecast']?['summary'] ?? f['forecast'] ?? '';
      final wind = f['wind']?['speed'] ?? {};
      final rh = f['relativeHumidity'] ?? f['relative_humidity'] ?? {};

      results.add({
        'date': dateStr,
        'max_c': (temp['high'] as num?)?.toDouble() ?? 0.0,
        'min_c': (temp['low'] as num?)?.toDouble() ?? 0.0,
        'condition': {'text': text},
        'glyph': _mapConditionToGlyph(text),
        'wind': {
          'low_kph': (wind['low'] as num?)?.toDouble() ?? 0.0,
          'high_kph': (wind['high'] as num?)?.toDouble() ?? 0.0,
        },
        'humidity': {
          'low': (rh['low'] as num?)?.toInt() ?? 0,
          'high': (rh['high'] as num?)?.toInt() ?? 0,
        },
        'chance_of_rain': i < precipChances.length ? precipChances[i] : 0,
        'source': 'nea',
      });
    }
    return results;
  }

  Future<Map<String, dynamic>?> fetchPSI(double lat, double lon) async {
    final psiRes = await http.get(Uri.parse('$_base/api/sg/psi'));
    if (psiRes.statusCode != 200) return null;
    
    final psi = jsonDecode(psiRes.body);
    final item = (psi['data']?['items'] as List?)?.firstOrNull;
    if (item == null) return null;

    final regions = (psi['data']?['regionMetadata'] as List?) ?? [];
    final nearest = _findNearestPoint(lat, lon, regions, (r) => r['labelLocation'] ?? r['label_location']);
    final regionName = (nearest?['name'] as String?)?.toLowerCase() ?? 'central';

    final psiMap = item['readings']?['psi_twenty_four_hourly'];
    final psiVal = psiMap is Map ? psiMap[regionName] : null;
    
    if (psiVal is num) {
      final val = psiVal.toInt();
      return {
        'aqi': val,
        'air_quality_text': _getAQIDescriptionFromPSI(val),
      };
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchRegionalOutlook() async {
    final day24Res = await http.get(Uri.parse('$_base/api/sg/twenty-four-hr-forecast'));
    if (day24Res.statusCode != 200) return [];
    final day24 = jsonDecode(day24Res.body);
    final data = day24['data'] ?? {};
    final record = (data['records'] as List?)?.firstOrNull ?? (data['items'] as List?)?.firstOrNull;
    if (record == null) return [];
    
    final List<Map<String, dynamic>> outlook = [];
    final periods = (record['periods'] as List?) ?? [];
    
    for (final p in periods) {
      final regions = p['regions'] ?? {};
      if (regions is Map) {
        for (final entry in regions.entries) {
          outlook.add({
            'region': entry.key,
            'text': entry.value?['text'] ?? '',
            'period_text': (p['timePeriod'] ?? p['time_period'] ?? {})['text'] ?? '',
            'start': (p['timePeriod'] ?? p['time_period'] ?? {})['start'],
            'end': (p['timePeriod'] ?? p['time_period'] ?? {})['end'],
          });
        }
      }
    }
    return outlook;
  }

  // --- Helpers ---

  Map<String, dynamic>? _findNearestPoint(double lat, double lon, List list, Function locGetter) {
    double bestDist = double.infinity;
    Map<String, dynamic>? best;
    for (final item in list) {
      try {
        final l = locGetter(item);
        final la = (l['latitude'] as num).toDouble();
        final lo = (l['longitude'] as num).toDouble();
        final d = _haversine(lat, lon, la, lo);
        if (d < bestDist) {
          bestDist = d;
          best = Map<String, dynamic>.from(item as Map);
        }
      } catch (_) {}
    }
    return best;
  }

  Map<String, dynamic>? _findNearestPointFromStations(double lat, double lon, List? stations) {
    if (stations == null) return null;
    double bestDist = double.infinity;
    Map<String, dynamic>? best;
    for (final s in stations) {
      try {
        final loc = s['location'] ?? s['label_location'];
        final la = (loc['latitude'] as num).toDouble();
        final lo = (loc['longitude'] as num).toDouble();
        final d = _haversine(lat, lon, la, lo);
        if (d < bestDist) {
          bestDist = d;
          best = Map<String, dynamic>.from(s as Map);
        }
      } catch (_) {}
    }
    return best;
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * (pi / 180);
    final dLon = (lon2 - lon1) * (pi / 180);
    final a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * (pi / 180)) * cos(lat2 * (pi / 180)) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  String _mapConditionToGlyph(String cond) {
    final c = cond.toLowerCase();
    if (c.contains('thunder') || c.contains('thundery')) return 'storm';
    if (c.contains('shower') || c.contains('rain')) return 'rain';
    if (c.contains('cloud')) return 'cloud';
    if (c.contains('clear') || c.contains('sunny')) return 'clear';
    return 'partly';
  }

  String _getAQIDescriptionFromPSI(int psi) {
    if (psi <= 50) return 'Good';
    if (psi <= 100) return 'Moderate';
    if (psi <= 200) return 'Unhealthy';
    if (psi <= 300) return 'Very Unhealthy';
    return 'Hazardous';
  }
}
