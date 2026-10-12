class Feeder {
  const Feeder({required this.id, required this.name});

  final int id;
  final String name;

  factory Feeder.fromJson(Map<String, dynamic> json) =>
      Feeder(id: json['id'] as int, name: json['name'] as String);
}

class Area {
  const Area({
    required this.id,
    required this.name,
    required this.city,
    required this.latitude,
    required this.longitude,
    this.feeders = const [],
  });

  final int id;
  final String name;
  final String city;
  final double latitude;
  final double longitude;
  final List<Feeder> feeders;

  factory Area.fromJson(Map<String, dynamic> json) => Area(
        id: json['id'] as int,
        name: json['name'] as String,
        city: json['city'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        feeders: [
          for (final f in (json['feeders'] as List<dynamic>? ?? []))
            Feeder.fromJson(f as Map<String, dynamic>),
        ],
      );
}
