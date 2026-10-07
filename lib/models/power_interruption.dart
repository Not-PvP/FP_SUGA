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
  });

  factory PowerInterruption.fromJson(Map<String, dynamic> json) {
    return PowerInterruption(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
      affectedAreas: (json['affectedAreas'] as List<dynamic>?)
              ?.map((area) => area.toString())
              .toList() ??
          [],
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      estimatedRestorationTime:
          json['estimatedRestorationTime']?.toString(),
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
    };
  }
}
