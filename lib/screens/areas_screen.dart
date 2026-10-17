import 'package:flutter/material.dart';
import 'package:suga/models/area.dart';
import 'package:suga/routes/app_routes.dart';
import 'package:suga/services/area_service.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:suga/providers/power_interruption_provider.dart';

class AreasScreen extends StatefulWidget {
  const AreasScreen({super.key, this.service, this.onAreaSelected});

  final AreaService? service;
  final VoidCallback? onAreaSelected;

  @override
  State<AreasScreen> createState() => _AreasScreenState();
}

class _AreasScreenState extends State<AreasScreen> {
  late final AreaService _service = widget.service ?? AreaService();
  late Future<List<Area>> _areas = _service.fetchAreas();
  String _search = '';
  Timer? _searchDebounce;

  void _searchAreas(String value) {
    _search = value;
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;

      setState(() {
        _areas = _service.fetchAreas(search: _search);
      });
    });
  }

  void _load() {
    setState(() {
      _areas = _service.fetchAreas(search: _search);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A0F),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose Your Area',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Select your location to check power updates.',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                  ),
                ],
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFFFFBF00),
                  ),
                  hintText: 'Search areas...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF111720),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF292F38)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF292F38)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFFFFBF00),
                      width: 1.2,
                    ),
                  ),
                ),
                textInputAction: TextInputAction.search,
                onChanged: _searchAreas,
              ),
            ),

            // All Areas label
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                'ALL AREAS',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ),

            // Existing area list
            Expanded(
              child: FutureBuilder<List<Area>>(
                future: _areas,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFFBF00),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _load,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFBF00),
                              foregroundColor: const Color(0xFF070A0F),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  final areas = snapshot.data!;
                  if (areas.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_off_outlined,
                            size: 56,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _search.trim().isEmpty
                                ? 'No areas available'
                                : 'No matching areas found',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _search.trim().isEmpty
                                ? 'Available areas will appear here.'
                                : 'Try searching with a different name.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                    itemCount: areas.length,
                    itemBuilder: (context, i) {
                      final area = areas[i];
                      final hasPowerOut = !context
                          .watch<PowerInterruptionProvider>()
                          .hasPowerInArea(area.id);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: hasPowerOut
                              ? const Color(0xFF1C1115)
                              : const Color(0xFF111720),
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () async {
                              await Navigator.pushNamed(
                                context,
                                AppRoutes.areaDetails,
                                arguments: areas[i].id,
                              );

                              if (!mounted) return;
                              widget.onAreaSelected?.call();
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: hasPowerOut
                                      ? const Color(0xFF71333A)
                                      : const Color(0xFF292F38),
                                  width: 1,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 4,
                                ),
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${area.name}, ${area.city}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: hasPowerOut
                                              ? const Color(0xFF35191D)
                                              : const Color(0xFF14271E),
                                            border: Border.all(
                                              color: hasPowerOut
                                                ? const Color(0xFFA9444D)
                                                : const Color(0xFF347653),
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: hasPowerOut
                                                      ? const Color(0xFFFF8A94)
                                                      : const Color(0xFF4ADE80),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                hasPowerOut
                                                    ? 'Power Out'
                                                    : 'Power On',
                                                style: TextStyle(
                                                  color: hasPowerOut
                                                    ? const Color(0xFFFFD6D9)
                                                    : const Color(0xFF86EFAC),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (hasPowerOut) ...[
                                          const SizedBox(width: 10),
                                          const Text(
                                            'Since 2:30 PM',
                                            style: TextStyle(
                                              color: Color(0xFFFCA5A5),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
