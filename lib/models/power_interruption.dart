class PowerInterruption {
  final String id;
  final String title;
  final String description;
  final String date;
  final String startTime;
  final String endTime;
  final List<String> affectedAreas;
  final String reason;
  final String status;
  final String? estimatedRestorationTime;

  // Ids from the API, used to filter by area and to send updates.
  final List<int> areaIds;
  final List<String> feeders;
  final List<int> feederIds;

  PowerInterruption({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.affectedAreas,
    required this.reason,
    required this.status,
    this.estimatedRestorationTime,
    this.areaIds = const [],
    this.feeders = const [],
    this.feederIds = const [],
  });

  // Accepts the backend's snake_case keys as well as the camelCase keys from toJson().
  factory PowerInterruption.fromJson(Map<String, dynamic> json) {
    return PowerInterruption(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      startTime: (json['start_time'] ?? json['startTime'])?.toString() ?? '',
      endTime: (json['end_time'] ?? json['endTime'])?.toString() ?? '',
      affectedAreas: _strings(json['affected_areas'] ?? json['affectedAreas']),
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      estimatedRestorationTime:
          (json['estimated_restoration'] ?? json['estimatedRestorationTime'])?.toString(),
      areaIds: _ints(json['area_ids'] ?? json['areaIds']),
      feeders: _strings(json['feeders']),
      feederIds: _ints(json['feeder_ids'] ?? json['feederIds']),
    );
  }

  static List<String> _strings(dynamic value) =>
      (value as List<dynamic>?)?.map((item) => item.toString()).toList() ?? [];

  static List<int> _ints(dynamic value) =>
      (value as List<dynamic>?)?.map((item) => (item as num).toInt()).toList() ?? [];

  PowerInterruption copyWith({
    String? id,
    String? title,
    String? description,
    String? date,
    String? startTime,
    String? endTime,
    List<String>? affectedAreas,
    String? reason,
    String? status,
    String? estimatedRestorationTime,
    List<int>? areaIds,
    List<String>? feeders,
    List<int>? feederIds,
  }) {
    return PowerInterruption(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      affectedAreas: affectedAreas ?? this.affectedAreas,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      estimatedRestorationTime: estimatedRestorationTime ?? this.estimatedRestorationTime,
      areaIds: areaIds ?? this.areaIds,
      feeders: feeders ?? this.feeders,
      feederIds: feederIds ?? this.feederIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'affectedAreas': affectedAreas,
      'reason': reason,
      'status': status,
      'estimatedRestorationTime': estimatedRestorationTime,
      'areaIds': areaIds,
      'feeders': feeders,
      'feederIds': feederIds,
    };
  }

  // The body for POST and PATCH /api/interruptions: only the writable fields,
  // with the snake_case keys the API expects. Server fields like id are left out.
  Map<String, dynamic> toRequestJson() {
    final restoration = estimatedRestorationTime;
    return {
      'title': title,
      'description': description,
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'reason': reason,
      // Left out when empty, so the server uses its default ('scheduled').
      if (status.isNotEmpty) 'status': status,
      'estimated_restoration': (restoration == null || restoration.isEmpty) ? null : restoration,
      'area_ids': areaIds,
      'feeder_ids': feederIds,
    };
  }
}
