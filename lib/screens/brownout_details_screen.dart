import 'package:flutter/material.dart';

class BrownoutDetailsScreen extends StatelessWidget {
  const BrownoutDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brownout Details'),
      ),
      body: const Center(
        child: Text('Brownout Details'),
      ),
    );
  }
}