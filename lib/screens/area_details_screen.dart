import 'package:flutter/material.dart';
import 'package:suga/models/area.dart';
import 'package:suga/services/area_service.dart';

class AreaDetailsScreen extends StatefulWidget {
  const AreaDetailsScreen({super.key, this.service});

  final AreaService? service;

  @override
  State<AreaDetailsScreen> createState() => _AreaDetailsScreenState();
}

class _AreaDetailsScreenState extends State<AreaDetailsScreen> {
  late final AreaService _service = widget.service ?? AreaService();
  Future<Area>? _area;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Receives the area id from the Areas screen.
    final id = ModalRoute.of(context)!.settings.arguments as int;
    _area ??= _service.fetchArea(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Area Details')),
      body: FutureBuilder<Area>(
        future: _area,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final area = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(area.name, style: Theme.of(context).textTheme.headlineMedium),
              Text(area.city),
              const SizedBox(height: 16),
              Text('Feeders', style: Theme.of(context).textTheme.titleMedium),
              if (area.feeders.isEmpty) const Text('No feeders listed'),
              for (final feeder in area.feeders) ListTile(title: Text(feeder.name)),
            ],
          );
        },
      ),
    );
  }
}
