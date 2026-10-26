import 'package:flutter/material.dart';
import 'package:suga/services/weather_service.dart';

class WeatherCard extends StatefulWidget {
  const WeatherCard({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    this.forecastDateTime,
  });

  final double latitude;
  final double longitude;
  final String locationName;

  // Null means current weather; otherwise, fetch the forecast for this time.
  final DateTime? forecastDateTime;

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  final WeatherService _weatherService = WeatherService();
  late Future<WeatherData> _weatherFuture;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  @override
  void didUpdateWidget(covariant WeatherCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.forecastDateTime != widget.forecastDateTime) {
      _loadWeather();
    }
  }

  void _loadWeather() {
    final dateTime = widget.forecastDateTime;

    _weatherFuture = dateTime == null
        ? _weatherService.fetchCurrentWeather(
            latitude: widget.latitude,
            longitude: widget.longitude,
          )
        : _weatherService.fetchForecast(
            latitude: widget.latitude,
            longitude: widget.longitude,
            dateTime: dateTime,
          );
  }

  String _weatherDescription(int code) {
    if (code == 0) return 'Clear';
    if (code <= 3) return 'Partly cloudy';
    if (code == 45 || code == 48) return 'Foggy';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code >= 61 && code <= 67) return 'Rainy';
    if (code >= 71 && code <= 77) return 'Snowy';
    if (code >= 80 && code <= 82) return 'Rain showers';
    if (code >= 85 && code <= 86) return 'Snow showers';
    if (code >= 95) return 'Thunderstorm';
    return 'Unknown';
  }

  IconData _weatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny_outlined;
    if (code <= 3) return Icons.cloud_outlined;
    if (code == 45 || code == 48) return Icons.foggy;
    if (code >= 95) return Icons.thunderstorm_outlined;
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return Icons.water_drop_outlined;
    }
    return Icons.cloud_outlined;
  }

  Widget _buildCardContents({
    required String temperature,
    required String description,
    required String rain,
    required String rainProbability,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111720),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF292F38), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF292315),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x80FFBF00)),
            ),
            child: Icon(icon, color: const Color(0xFFFFBF00), size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$temperature · $description',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.water_drop_outlined,
                          color: Color(0xFF9CA3AF),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Rain: $rain · Chance: $rainProbability',
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: Color(0xFF9CA3AF),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.locationName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherData>(
      future: _weatherFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildCardContents(
            temperature: '--°C',
            description: 'Weather unavailable',
            rain: '-- mm',
            icon: Icons.cloud_off_outlined,
            rainProbability: '--%',
          );
        }

        if (!snapshot.hasData) {
          return _buildCardContents(
            temperature: '--°C',
            description: 'Loading weather...',
            rain: '-- mm',
            icon: Icons.cloud_outlined,
            rainProbability: '--%',
          );
        }

        final weather = snapshot.data!;

        return _buildCardContents(
          temperature: '${weather.temperature.round()}°C',
          description: _weatherDescription(weather.weatherCode),
          rain: '${weather.rain.toStringAsFixed(1)} mm',
          icon: _weatherIcon(weather.weatherCode),
          rainProbability: weather.rainProbability == null
              ? 'N/A'
              : '${weather.rainProbability!.round()}%',
        );
      },
    );
  }
}
