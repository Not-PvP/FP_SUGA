import 'package:flutter/material.dart';
import 'package:suga/models/power_interruption.dart';

class ScheduledBrownoutsScreen extends StatelessWidget {
  const ScheduledBrownoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brownout = PowerInterruption(
        id: '1',
        title: 'Scheduled Brownout - Jaro',
        description: 'Planned power interruption',
        date: 'October 10, 2026',
        startTime: '9:00 AM',
        endTime: '12:00 PM',
        affectedAreas: ['Jaro'],
        reason: 'Maintenance',
        status: 'Scheduled',
      );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled Brownouts'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.pushNamed(
              context,
              '/brownout_details',
              arguments: brownout,
            );
          },
          child: const Text('View Brownout Details'),
        ),
      ),
    );
  }
}