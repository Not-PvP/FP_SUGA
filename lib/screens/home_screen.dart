import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/areas');
              },
              child: const Text('Go to Areas'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/brownouts');
              },
              child: const Text('Go to Scheduled Brownouts'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/notifications');
              },
              child: const Text('Go to Notifications'),
            ),
          ],
        ),
      ),
    );
  }
}
