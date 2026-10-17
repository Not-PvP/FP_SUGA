import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:suga/providers/power_interruption_provider.dart';

class PowerStatusWidget extends StatelessWidget {
  const PowerStatusWidget({super.key, this.areaId});

  final int? areaId;

  @override
  Widget build(BuildContext context) {
    return Consumer<PowerInterruptionProvider>(
      builder: (context, provider, child) {
        final displayAreaId = areaId ?? provider.selectedAreaId;

        if (displayAreaId == null) {
          return const SizedBox.shrink();
        }

        final hasPower = provider.hasPowerInArea(displayAreaId);

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -20),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (hasPower)
                            ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: 65,
                                sigmaY: 65,
                              ),
                              child: Container(
                                width: 340,
                                height: 340,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(
                                    0xFFFFBF00,
                                  ).withValues(alpha: 0.35),
                                ),
                              ),
                            ),
                          SvgPicture.asset(
                            hasPower
                                ? 'assets/images/bulb_on.svg'
                                : 'assets/images/bulb_off.svg',
                            width: 300,
                            height: 300,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 0),

              Text(
                hasPower ? 'No Outage Reported' : 'Power Outage In Your Area',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              if (hasPower)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.access_time,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'As of ${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year} • ${TimeOfDay.fromDateTime(DateTime.now()).format(context)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Since [outage start time]',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Est. restoration: [estimated time]',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
