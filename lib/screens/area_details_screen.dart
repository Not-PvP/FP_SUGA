import 'package:flutter/material.dart';

class AreaDetailsScreen extends StatelessWidget {
  const AreaDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final area = ModalRoute.of(context)?.settings.arguments as String;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Area Details'),
      ),
      body: Center(
        child: Text(area),
      ),
    );
  }
}