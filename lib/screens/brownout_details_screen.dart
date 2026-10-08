import 'package:flutter/material.dart';
import 'package:suga/models/power_interruption.dart';

class BrownoutDetailsScreen extends StatelessWidget {
  const BrownoutDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brownout = ModalRoute.of(context)?.settings.arguments as PowerInterruption;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brownout Details'),
      ),
      body: Center(
        child: Text(
          'Title: ${brownout.title}\n'
          'Description: ${brownout.description}\n'
          'Date: ${brownout.date}\n'
          'Start Time: ${brownout.startTime}\n'
          'End Time: ${brownout.endTime}\n'
          'Affected Areas: ${brownout.affectedAreas.join(", ")}\n'
          'Reason: ${brownout.reason}\n'
          'Status: ${brownout.status}',
        ),
      ),
    );
  }
}