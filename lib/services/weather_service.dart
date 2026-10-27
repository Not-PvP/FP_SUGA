import 'dart:convert';

import 'package:http/http.dart' as http;

class WeatherData {
  const WeatherData({
    required this.temperature,
    required this.weatherCode,
    required this.rain,
    this.time,
    this.rainProbability,
  });

  final double temperature;
  final int weatherCode;
  final double rain;
  final DateTime? time;
  final double? rainProbability;

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: (json['temperature_2m'] as num).toDouble(),
      weatherCode: json['weather_code'] as int,
      rain: (json['rain'] as num?)?.toDouble() ?? 0,
      rainProbability: (json['precipitation_probability'] as num?)?.toDouble(),
      time: json['time'] == null
          ? null
          : DateTime.tryParse(json['time'] as String),
    );
  }
}

class WeatherService {
  static const _baseUrl = 'api.open-meteo.com';

  /// Fetches the current weather at the given coordinates.
  Future<WeatherData> fetchCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https(_baseUrl, '/v1/forecast', {
      'latitude': '$latitude',
      'longitude': '$longitude',
      'current': 'temperature_2m,weather_code,rain,precipitation_probability',
      'timezone': 'auto',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Unable to load current weather.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return WeatherData.fromJson(body['current'] as Map<String, dynamic>);
  }

  /// Fetches hourly forecast data for a specific local date and time.
  Future<WeatherData> fetchForecast({
    required double latitude,
    required double longitude,
    required DateTime dateTime,
  }) async {
    final date =
        '${dateTime.year.toString().padLeft(4, '0')}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')}';
    final hour = dateTime.hour.toString().padLeft(2, '0');

    final uri = Uri.https(_baseUrl, '/v1/forecast', {
      'latitude': '$latitude',
      'longitude': '$longitude',
      'hourly': 'temperature_2m,weather_code,rain,precipitation_probability',
      'start_date': date,
      'end_date': date,
      'timezone': 'auto',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Unable to load weather forecast.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final hourly = body['hourly'] as Map<String, dynamic>;
    final times = hourly['time'] as List<dynamic>;
    final index = times.indexWhere((value) => value == '${date}T$hour:00');

    if (index == -1) {
      throw Exception('Forecast unavailable for that time.');
    }

    return WeatherData.fromJson({
      'time': times[index],
      'temperature_2m': (hourly['temperature_2m'] as List<dynamic>)[index],
      'weather_code': (hourly['weather_code'] as List<dynamic>)[index],
      'rain': (hourly['rain'] as List<dynamic>)[index],
      'precipitation_probability':
          (hourly['precipitation_probability'] as List<dynamic>)[index],
    });
  }
}
