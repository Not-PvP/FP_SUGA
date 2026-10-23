import 'package:flutter/material.dart';

class WeatherCard extends StatelessWidget {
  const WeatherCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111720),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF292F38), width: 1),
      ),
      child: Row(
        children: [
          // Weather icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF292315),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x80FFBF00)),
            ),
            child: const Icon(
              Icons.cloud_outlined,
              color: Color(0xFFFFBF00),
              size: 26,
            ),
          ),

          const SizedBox(width: 12),

          // Weather details
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '28°C · Cloudy',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.water_drop_outlined,
                      color: Color(0xFF9CA3AF),
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Rain: 0 mm',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                    ),
                    SizedBox(width: 12),
                    Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFF9CA3AF),
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Iloilo City',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                        ),
                      ),
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
}
