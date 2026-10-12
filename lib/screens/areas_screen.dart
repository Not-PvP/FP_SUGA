import 'package:flutter/material.dart';
import 'package:suga/models/area.dart';
import 'package:suga/routes/app_routes.dart';
import 'package:suga/services/area_service.dart';

class AreasScreen extends StatefulWidget {
  const AreasScreen({super.key, this.service});

  final AreaService? service;

  @override
  State<AreasScreen> createState() => _AreasScreenState();
}

class _AreasScreenState extends State<AreasScreen> {
  late final AreaService _service = widget.service ?? AreaService();
  late Future<List<Area>> _areas = _service.fetchAreas();
  String _search = '';

  void _load() => setState(() => _areas = _service.fetchAreas(search: _search));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Areas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search areas',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.search,
              onChanged: (value) => _search = value,
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Area>>(
              future: _areas,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${snapshot.error}', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  );
                }
                final areas = snapshot.data!;
                if (areas.isEmpty) return const Center(child: Text('No areas found'));
                return ListView.builder(
                  itemCount: areas.length,
                  itemBuilder: (context, i) => ListTile(
                    title: Text(areas[i].name),
                    subtitle: Text(areas[i].city),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.areaDetails,
                      arguments: areas[i].id,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
