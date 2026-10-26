import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/utils/advisory_time.dart';
import 'package:timezone/timezone.dart' as tz;

class PowerStatusWidget extends StatefulWidget {
  const PowerStatusWidget({super.key, this.areaId});

  final int? areaId;

  @override
  State<PowerStatusWidget> createState() => _PowerStatusWidgetState();
}

class _PowerStatusWidgetState extends State<PowerStatusWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _glowScale;
  late final Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _glowScale = Tween<double>(begin: 0.85, end: 1.12).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _glowOpacity = Tween<double>(begin: 0.18, end: 0.42).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PowerInterruptionProvider>(
      builder: (context, provider, child) {
        final displayAreaId = widget.areaId ?? provider.selectedAreaId;

        if (displayAreaId == null) {
          return const SizedBox.shrink();
        }

        final now = manila;
        final currentTime = tz.TZDateTime.now(now);

        final currentAdvisories = provider
            .interruptionsForArea(displayAreaId)
            .where((item) {
              final status = item.status.trim().toLowerCase();

              if (status == 'cancelled' ||
                  status == 'canceled' ||
                  status == 'completed') {
                return false;
              }

              final start = advisoryStart(item);
              final end = advisoryEnd(item);

              if (start == null || end == null) return false;

              return !currentTime.isBefore(start) && currentTime.isBefore(end);
            })
            .toList();

        final outage = currentAdvisories.isEmpty
            ? null
            : currentAdvisories.first;

        final hasPower = outage == null;
        if (hasPower && !_glowController.isAnimating) {
          _glowController.repeat(reverse: true);
        } else if (!hasPower && _glowController.isAnimating) {
          _glowController.stop();
          _glowController.value = 0;
        }

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
                            AnimatedBuilder(
                              animation: _glowController,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _glowScale.value,
                                  child: Opacity(
                                    opacity: _glowOpacity.value,
                                    child: child,
                                  ),
                                );
                              },

                              child: ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: 65,
                                  sigmaY: 65,
                                ),
                                child: Container(
                                  width: 340,
                                  height: 340,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFFFBF00),
                                  ),
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
                      'As of ${currentTime.month}/${currentTime.day}/${currentTime.year} • '
                      '${_formatAdvisoryTime('${currentTime.hour}:${currentTime.minute.toString().padLeft(2, '0')}', context)}',
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
                        Text(
                          'Since ${_formatAdvisoryTime('${advisoryStart(outage)!.hour}:${advisoryStart(outage)!.minute.toString().padLeft(2, '0')}', context)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Est. restoration: ${_formatAdvisoryTime((outage.estimatedRestorationTime?.trim().isNotEmpty == true) ? outage.estimatedRestorationTime!.trim() : outage.endTime, context)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
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

String _formatAdvisoryTime(String? time, BuildContext context) {
  if (time == null || time.trim().isEmpty) return '—';

  final parts = time.trim().split(':');
  if (parts.length < 2) return time;

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);

  if (hour == null || minute == null) return time;

  return TimeOfDay(hour: hour, minute: minute).format(context);
}
