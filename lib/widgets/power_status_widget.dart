import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:suga/models/power_interruption.dart';
import 'package:suga/providers/power_interruption_provider.dart';
import 'package:suga/routes/app_routes.dart';
import 'package:suga/theme/app_theme.dart';
import 'package:suga/utils/advisory_time.dart';
import 'package:suga/utils/format.dart';

// The bulb hero: is there power in this area right now, and when is the next
// brownout? Used on Home and Area Details.
class PowerStatusWidget extends StatefulWidget {
  const PowerStatusWidget({super.key, this.areaId, this.bulbSize = 180});

  // Defaults to the home area.
  final int? areaId;
  final double bulbSize;

  @override
  State<PowerStatusWidget> createState() => _PowerStatusWidgetState();
}

class _PowerStatusWidgetState extends State<PowerStatusWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  // Started and stopped after the frame, never during build.
  void _syncGlow(bool animate) {
    if (!mounted) return;
    if (animate && !_glow.isAnimating) {
      _glow.repeat(reverse: true);
    } else if (!animate && _glow.isAnimating) {
      _glow.stop();
    }
  }

  void _open(PowerInterruption advisory) {
    Navigator.pushNamed(context, AppRoutes.brownoutDetails, arguments: advisory);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PowerInterruptionProvider>();
    final areaId = widget.areaId ?? provider.selectedAreaId;
    if (areaId == null) return const SizedBox.shrink();

    final loaded = provider.hasLoaded;
    final outage = loaded ? provider.currentOutage(areaId) : null;
    final next = loaded && outage == null ? provider.nextOutage(areaId) : null;
    final powerOn = loaded && outage == null;
    // Respect "Remove animations" in the phone's accessibility settings.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncGlow(powerOn && !reduceMotion));

    final String headline;
    if (!loaded) {
      headline = provider.error != null ? 'Status unavailable' : 'Checking your area…';
    } else if (outage != null) {
      headline = 'Brownout in progress';
    } else {
      headline = 'Power is on';
    }

    return Column(
      children: [
        Semantics(
          image: true,
          label: powerOn ? 'Light bulb on' : 'Light bulb off',
          child: SizedBox(
            height: widget.bulbSize,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (powerOn) _buildGlow(reduceMotion),
                // The artwork has empty space around the bulb, so draw it a bit larger.
                OverflowBox(
                  maxWidth: widget.bulbSize * 1.3,
                  maxHeight: widget.bulbSize * 1.3,
                  child: Opacity(
                    opacity: loaded ? 1 : 0.45,
                    child: SvgPicture.asset(
                      powerOn ? 'assets/images/bulb_on.svg' : 'assets/images/bulb_off.svg',
                      width: widget.bulbSize * 1.3,
                      height: widget.bulbSize * 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(
            headline,
            textAlign: TextAlign.center,
            style: AppText.headline.copyWith(
              color: outage != null ? AppColors.outage : AppColors.text,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (outage != null)
          _buildOutageDetails(outage)
        else if (next != null)
          _buildNext(next)
        else if (loaded)
          const Text(
            'No brownouts scheduled for this area.',
            textAlign: TextAlign.center,
            style: AppText.muted,
          ),
        if (!loaded && provider.error != null) ...[
          Text(provider.error!, textAlign: TextAlign.center, style: AppText.muted),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: provider.loadInterruptions, child: const Text('Retry')),
        ],
        if (provider.lastUpdated != null) ...[
          const SizedBox(height: 12),
          Text(
            provider.error != null
                ? "Couldn't refresh. Showing data from ${DateFormat('h:mm a').format(provider.lastUpdated!)}."
                : 'Updated ${DateFormat('h:mm a').format(provider.lastUpdated!)}',
            textAlign: TextAlign.center,
            style: AppText.small,
          ),
        ],
      ],
    );
  }

  Widget _buildGlow(bool reduceMotion) {
    // A radial gradient instead of a blur filter: it looks the same and is much
    // cheaper to draw every frame on budget phones.
    final glow = Container(
      width: widget.bulbSize * 1.25,
      height: widget.bulbSize * 1.25,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.amber.withValues(alpha: 0.38),
            AppColors.amber.withValues(alpha: 0),
          ],
        ),
      ),
    );
    if (reduceMotion) return glow;
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) => Transform.scale(
        scale: 0.9 + 0.12 * _glow.value,
        child: Opacity(opacity: 0.65 + 0.35 * _glow.value, child: child),
      ),
      child: glow,
    );
  }

  Widget _buildOutageDetails(PowerInterruption outage) {
    final restoration = outage.estimatedRestorationTime?.trim() ?? '';
    final day = DateTime.tryParse(outage.date);
    final since = day != null && !DateUtils.isSameDay(day, DateTime.now())
        ? 'Since ${formatDay(day)}, ${formatClock(outage.startTime)}'
        : 'Since ${formatClock(outage.startTime)}';
    final back = restoration.isNotEmpty
        ? 'Expected back by ${formatClock(restoration)}'
        : 'Scheduled to end at ${formatClock(outage.endTime)}';

    return Column(
      children: [
        Text(
          '$since. $back.',
          textAlign: TextAlign.center,
          style: AppText.body,
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => _open(outage),
          icon: const Icon(Icons.description_outlined, size: 18),
          label: const Text('View advisory'),
        ),
      ],
    );
  }

  Widget _buildNext(PowerInterruption next) {
    final start = advisoryStart(next);
    final day = DateTime.tryParse(next.date);
    final countdown = start == null ? '' : ' ${lowerFirst(timeUntil(start, DateTime.now()))}';
    final when = [
      if (day != null) formatDay(day),
      formatTimeRange(next),
    ].join(' · ');

    return Material(
      color: AppColors.amberSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: AppColors.amber.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(next),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_rounded, color: AppColors.amber, size: 22),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next brownout$countdown',
                      style: const TextStyle(
                        fontFamily: AppText.font,
                        color: AppColors.amber,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(when, style: AppText.muted.copyWith(color: AppColors.textSoft)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: AppColors.amber),
            ],
          ),
        ),
      ),
    );
  }
}
