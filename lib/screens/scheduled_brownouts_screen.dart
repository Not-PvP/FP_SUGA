import 'package:flutter/material.dart';

class ScheduledBrownoutsScreen extends StatelessWidget {
  const ScheduledBrownoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled Brownouts'),
      ),
      body: const Center(
        child: Text('Scheduled Brownouts'),
      ),
    );
  }
}