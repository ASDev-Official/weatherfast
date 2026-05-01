import 'dart:math';

class WeatherInsightsService {
  /// Generate comprehensive weather insights
  Map<String, dynamic> generateInsights({
    required String condition,
    required int currentTemp,
    required int highTemp,
    required int lowTemp,
    required int humidity,
    required double windSpeed,
    required double uvIndex,
    required int aqi,
    required List<Map<String, dynamic>> dailyForecasts,
    required String country,
  }) {
    final trends = _analyzeTrends(dailyForecasts);
    final risks = _assessRisks(
      condition: condition,
      temp: currentTemp,
      high: highTemp,
      low: lowTemp,
      humidity: humidity,
      wind: windSpeed,
      uv: uvIndex,
      aqi: aqi,
    );

    return {
      'summary': _generateSummary(risks, trends),
      'recommendations': _generateRecommendations(risks, trends),
      'riskScores': risks,
      'trends': trends,
      'activities': _generateActivitySuggestions(risks, currentTemp, condition),
      'healthTips': _generateHealthTips(risks, uvIndex, currentTemp),
      'clothingAdvice':
          _generateClothingAdvice(currentTemp, highTemp, lowTemp, condition),
      'hourlyInsights': _generateHourlyInsights(dailyForecasts),
      'weekAhead': _generateWeekAheadInsights(dailyForecasts),
      'bestTimes': _findBestTimes(dailyForecasts, country),
    };
  }

  Map<String, double> _assessRisks({
    required String condition,
    required int temp,
    required int high,
    required int low,
    required int humidity,
    required double wind,
    required double uv,
    required int aqi,
  }) {
    return {
      'rain': _computeRainRisk(condition, humidity),
      'heat': _computeHeatRisk(high),
      'cold': _computeColdRisk(low),
      'wind': _computeWindRisk(wind),
      'uv': _computeUVRisk(uv),
      'air': _computeAirQualityRisk(aqi),
    };
  }

  double _computeAirQualityRisk(int aqi) {
    if (aqi >= 200) return 1.0;
    if (aqi >= 150) return 0.8;
    if (aqi >= 120) return 0.6;
    if (aqi >= 80) return 0.4;
    if (aqi >= 50) return 0.2;
    return 0.0;
  }

  double _computeRainRisk(String condition, int humidity) {
    double risk = 0.0;
    final lower = condition.toLowerCase();
    if (lower.contains('rain') || lower.contains('drizzle')) {
      risk += 0.8;
    } else if (lower.contains('cloud') || lower.contains('overcast')) {
      risk += 0.3;
    }
    if (humidity > 80) risk += 0.2;
    if (humidity > 90) risk += 0.1;
    return min(1.0, risk);
  }

  double _computeHeatRisk(int highTemp) {
    if (highTemp >= 35) return 1.0;
    if (highTemp >= 32) return 0.8;
    if (highTemp >= 30) return 0.6;
    if (highTemp >= 28) return 0.3;
    return 0.0;
  }

  double _computeColdRisk(int lowTemp) {
    if (lowTemp <= -10) return 1.0;
    if (lowTemp <= 0) return 0.8;
    if (lowTemp <= 5) return 0.5;
    if (lowTemp <= 10) return 0.2;
    return 0.0;
  }

  double _computeWindRisk(double windKph) {
    if (windKph >= 50) return 1.0;
    if (windKph >= 40) return 0.8;
    if (windKph >= 30) return 0.5;
    if (windKph >= 20) return 0.2;
    return 0.0;
  }

  double _computeUVRisk(double uv) {
    if (uv >= 11) return 1.0;
    if (uv >= 8) return 0.8;
    if (uv >= 6) return 0.6;
    if (uv >= 3) return 0.3;
    return 0.0;
  }

  Map<String, dynamic> _analyzeTrends(
      List<Map<String, dynamic>> dailyForecasts) {
    if (dailyForecasts.isEmpty) {
      return {'direction': 'stable', 'intensity': 0.0};
    }

    final first3Avg = _averageTemp(
        dailyForecasts.take(min(3, dailyForecasts.length)).toList());
    final last3 = dailyForecasts.length > 3
        ? dailyForecasts.sublist(max(0, dailyForecasts.length - 3))
        : dailyForecasts;
    final last3Avg = _averageTemp(last3);

    final direction = last3Avg > first3Avg
        ? 'warming'
        : last3Avg < first3Avg
            ? 'cooling'
            : 'stable';
    final intensity = (last3Avg - first3Avg).abs() / 20;

    return {
      'direction': direction,
      'intensity': min(1.0, intensity),
      'tempChange': (last3Avg - first3Avg).round(),
    };
  }

  double _averageTemp(List<Map<String, dynamic>> forecasts) {
    if (forecasts.isEmpty) return 20.0;
    double sum = 0;
    int count = 0;
    for (var f in forecasts) {
      final max = f['day']?['maxtemp_c'] as num?;
      if (max != null) {
        sum += max.toDouble();
        count++;
      }
    }
    return count > 0 ? sum / count : 20.0;
  }

  List<Map<String, String>> _generateActivitySuggestions(
      Map<String, double> risks, int temp, String condition) {
    final activities = <Map<String, String>>[];

    // Check if air quality is poor
    final poorAirQuality = risks['air'] != null && risks['air']! > 0.5;

    if (poorAirQuality) {
      activities.add({
        'icon': '😷',
        'title': 'Limit Outdoor Effort',
        'description': 'Air quality is poor—favor light or indoor activities',
      });
      // Skip outdoor activity suggestions when air quality is poor
      activities.add({
        'icon': '🏛️',
        'title': 'Indoor Activities',
        'description': 'Visit museums, cafes, or indoor entertainment',
      });
      return activities;
    }

    if (risks['rain']! < 0.3 && temp > 15 && temp < 30) {
      activities.add({
        'icon': '🚴',
        'title': 'Perfect for Cycling',
        'description':
            'Great weather for a bike ride—mild temps and clear skies',
      });
    }

    if (risks['heat']! < 0.4 && risks['rain']! < 0.4) {
      activities.add({
        'icon': '⚽',
        'title': 'Outdoor Sports',
        'description': 'Ideal conditions for outdoor activities and sports',
      });
    }

    if (temp > 25 && risks['rain']! < 0.5) {
      activities.add({
        'icon': '🏖️',
        'title': 'Beach Day',
        'description': 'Perfect beach weather—bring sunscreen!',
      });
    }

    if (risks['rain']! > 0.6) {
      activities.add({
        'icon': '🏛️',
        'title': 'Indoor Activities',
        'description': 'Visit museums, cafes, or indoor entertainment',
      });
    }

    if (temp < 15 && risks['rain']! < 0.5) {
      activities.add({
        'icon': '🥾',
        'title': 'Hiking Weather',
        'description': 'Cool and comfortable for a nature walk',
      });
    }

    return activities.isEmpty
        ? [
            {
              'icon': '🌤️',
              'title': 'General Activities',
              'description': 'Moderate weather—plan accordingly',
            }
          ]
        : activities;
  }

  List<Map<String, String>> _generateHealthTips(
      Map<String, double> risks, double uv, int temp) {
    final tips = <Map<String, String>>[];

    if (risks['air'] != null && risks['air']! > 0.5) {
      tips.add({
        'icon': '😷',
        'title': 'Air Quality Alert',
        'description':
            'Consider a mask outdoors and limit intense activity until air improves.',
        'severity': 'high',
      });
    }

    if (risks['uv']! > 0.6) {
      tips.add({
        'icon': '☀️',
        'title': 'UV Protection Critical',
        'description':
            'Apply SPF 30+ sunscreen every 2 hours. Wear sunglasses and a hat.',
        'severity': 'high',
      });
    }

    if (risks['heat']! > 0.7) {
      tips.add({
        'icon': '💧',
        'title': 'Stay Hydrated',
        'description':
            'Drink water regularly. Avoid prolonged sun exposure 11am-3pm.',
        'severity': 'high',
      });
    }

    if (risks['cold']! > 0.6) {
      tips.add({
        'icon': '🧊',
        'title': 'Cold Weather Alert',
        'description':
            'Watch for frostbite. Layer clothing and cover extremities.',
        'severity': 'high',
      });
    }

    if (risks['wind']! > 0.5) {
      tips.add({
        'icon': '💨',
        'title': 'Wind Advisory',
        'description': 'Secure loose items. Be cautious when driving.',
        'severity': 'medium',
      });
    }

    if (temp > 20 && temp < 25 && risks['rain']! < 0.3) {
      tips.add({
        'icon': '✨',
        'title': 'Optimal Conditions',
        'description':
            'Perfect weather for physical activity and outdoor time.',
        'severity': 'low',
      });
    }

    return tips;
  }

  Map<String, String> _generateClothingAdvice(
      int current, int high, int low, String condition) {
    String advice = '';
    String icon = '👕';

    if (high > 30) {
      icon = '🩳';
      advice = 'Light, breathable clothing. Hat and sunglasses recommended.';
    } else if (high > 25) {
      icon = '👕';
      advice = 'Comfortable summer wear. Light layers for morning/evening.';
    } else if (high > 20) {
      icon = '👖';
      advice = 'Long sleeves or light jacket recommended.';
    } else if (high > 15) {
      icon = '🧥';
      advice = 'Jacket or sweater needed. Long pants suggested.';
    } else if (high > 10) {
      icon = '🧥';
      advice = 'Warm jacket essential. Layer up for comfort.';
    } else {
      icon = '🧤';
      advice = 'Heavy winter coat, gloves, and warm layers required.';
    }

    if (condition.toLowerCase().contains('rain')) {
      advice += ' Bring waterproof gear.';
      icon = '☔';
    }

    return {'icon': icon, 'advice': advice};
  }

  List<Map<String, dynamic>> _generateHourlyInsights(
      List<Map<String, dynamic>> dailyForecasts) {
    final insights = <Map<String, dynamic>>[];

    if (dailyForecasts.isEmpty) return insights;

    final today = dailyForecasts.first;
    final hourly = (today['hour'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (hourly.length >= 24) {
      // Morning (6-9am)
      final morningTemps = hourly
          .sublist(6, 10)
          .map((h) => h['temp_c'] as num?)
          .whereType<num>();
      if (morningTemps.isNotEmpty) {
        final avgMorning =
            morningTemps.reduce((a, b) => a + b) / morningTemps.length;
        insights.add({
          'time': 'Morning',
          'temp': avgMorning.round(),
          'insight': avgMorning < 10
              ? 'Chilly start—extra layer needed'
              : 'Comfortable morning temperatures',
        });
      }

      // Afternoon (12-3pm)
      final afternoonTemps = hourly
          .sublist(12, 16)
          .map((h) => h['temp_c'] as num?)
          .whereType<num>();
      if (afternoonTemps.isNotEmpty) {
        final avgAfternoon =
            afternoonTemps.reduce((a, b) => a + b) / afternoonTemps.length;
        insights.add({
          'time': 'Afternoon',
          'temp': avgAfternoon.round(),
          'insight': avgAfternoon > 30
              ? 'Peak heat—seek shade'
              : 'Pleasant afternoon expected',
        });
      }

      // Evening (6-9pm)
      final eveningTemps = hourly
          .sublist(18, 22)
          .map((h) => h['temp_c'] as num?)
          .whereType<num>();
      if (eveningTemps.isNotEmpty) {
        final avgEvening =
            eveningTemps.reduce((a, b) => a + b) / eveningTemps.length;
        insights.add({
          'time': 'Evening',
          'temp': avgEvening.round(),
          'insight': avgEvening < 15
              ? 'Cool evening—bring a jacket'
              : 'Mild evening conditions',
        });
      }
    }

    return insights;
  }

  Map<String, String> _generateWeekAheadInsights(
      List<Map<String, dynamic>> dailyForecasts) {
    if (dailyForecasts.length < 7) {
      return {'summary': 'Limited forecast data available'};
    }

    final temps = dailyForecasts
        .take(7)
        .map((d) => d['day']?['maxtemp_c'] as num?)
        .whereType<num>()
        .toList();

    if (temps.isEmpty) {
      return {'summary': 'Forecast data unavailable'};
    }

    final avgTemp = temps.reduce((a, b) => a + b) / temps.length;
    final maxTemp = temps.reduce(max);
    final minTemp = temps.reduce(min);

    String summary = '';
    if (maxTemp - minTemp > 10) {
      summary =
          'Variable week ahead with ${(maxTemp - minTemp).round()}°C temperature swing. ';
    } else {
      summary = 'Stable conditions expected with consistent temperatures. ';
    }

    if (avgTemp > 25) {
      summary += 'Generally warm throughout the week.';
    } else if (avgTemp < 15) {
      summary += 'Cool weather pattern persisting.';
    } else {
      summary += 'Moderate temperatures prevailing.';
    }

    return {'summary': summary, 'avgTemp': avgTemp.round().toString()};
  }

  Map<String, String> _findBestTimes(
      List<Map<String, dynamic>> dailyForecasts, String country) {
    if (country.toLowerCase().contains('singapore')) {
      return {
        'title': 'Best Time: 7-9 AM & 5-8 PM',
        'description': 'Optimal conditions for outdoor activities in Singapore',
      };
    }

    if (dailyForecasts.isEmpty) {
      return {
        'title': 'No data',
        'description': 'Unable to determine best times'
      };
    }

    final today = dailyForecasts.first;
    final hourly = (today['hour'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (hourly.isEmpty) {
      return {
        'title': 'Limited data',
        'description': 'Hourly data unavailable'
      };
    }

    // Find hour with best conditions (moderate temp, no rain, low wind)
    int bestHour = 12; // default to noon
    double bestScore = -1;

    for (int i = 6; i < 20; i++) {
      if (i >= hourly.length) break;
      final hour = hourly[i];
      final temp = (hour['temp_c'] as num?)?.toDouble() ?? 20;
      final rain = (hour['chance_of_rain'] as num?)?.toDouble() ?? 0;
      final wind = (hour['wind_kph'] as num?)?.toDouble() ?? 0;

      // Score based on ideal conditions: 20-25°C, low rain, low wind
      double score = 100 -
          (temp - 22.5).abs() * 2 - // Prefer 20-25°C
          rain / 2 - // Penalize rain chance
          wind / 4; // Penalize wind

      if (score > bestScore) {
        bestScore = score;
        bestHour = i;
      }
    }

    final hourStr = bestHour == 12
        ? '12 PM'
        : bestHour > 12
            ? '${bestHour - 12} PM'
            : '$bestHour AM';

    return {
      'title': 'Best Time: $hourStr',
      'description': 'Optimal conditions for outdoor activities',
    };
  }

  List<String> _generateRecommendations(
      Map<String, double> risks, Map<String, dynamic> trends) {
    final recs = <String>[];

    if (risks['rain']! > 0.6) {
      recs.add('☔ Bring an umbrella—rain likely');
    }
    if (risks['heat']! > 0.7) {
      recs.add('🌡️ Stay hydrated—heat warning');
    } else if (risks['heat']! > 0.4) {
      recs.add('☀️ Apply sunscreen');
    }
    if (risks['cold']! > 0.7) {
      recs.add('🧊 Bundle up—cold weather ahead');
    }
    if (risks['wind']! > 0.6) {
      recs.add('💨 Secure loose items—strong winds');
    }
    if (risks['uv']! > 0.6) {
      recs.add('🛡️ High UV—protect your skin');
    }
    if (risks['air'] != null && risks['air']! > 0.6) {
      recs.add('😷 Air quality is poor—limit outdoor exertion');
    }
    if (trends['direction'] == 'warming') {
      recs.add('📈 Warming trend—dress in layers');
    } else if (trends['direction'] == 'cooling') {
      recs.add('📉 Cooling trend ahead');
    }

    return recs.isEmpty ? ['✨ Pleasant weather expected'] : recs;
  }

  String _generateSummary(
      Map<String, double> risks, Map<String, dynamic> trends) {
    final topRisks = risks.entries.where((e) => e.value > 0.5).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (topRisks.isEmpty) return 'All systems go—great conditions ahead!';

    final risk = topRisks.first;
    switch (risk.key) {
      case 'rain':
        return 'Rainy day incoming—prepare accordingly';
      case 'heat':
        return 'Hot and intense—stay cool';
      case 'cold':
        return 'Frigid conditions—bundle up';
      case 'wind':
        return 'Windy day—hold onto your hat';
      case 'uv':
        return 'Strong UV—protect yourself';
      case 'air':
        return 'Air quality is poor—take it easy outside';
      default:
        return 'Variable conditions expected';
    }
  }
}
