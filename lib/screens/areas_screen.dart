import 'package:flutter/material.dart';

class AreasScreen extends StatelessWidget {
  const AreasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Areas'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.pushNamed(
              context,
              '/area_details',
              arguments: 'Jaro',
            );
          },
          child: const Text('View Area Details'),
        ),
      ),
    );
  }
}