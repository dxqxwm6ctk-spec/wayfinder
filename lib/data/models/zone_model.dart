import '../../domain/entities/zone.dart';

class ZoneModel {
  const ZoneModel({
    required this.id,
    required this.name,
    required this.studentsWaiting,
    required this.severity,
    this.assignedBus,
  });

  factory ZoneModel.fromJson(Map<String, dynamic> json) {
    return ZoneModel(
      id: json['id'] as String,
      name: json['name'] as String,
      studentsWaiting: json['studentsWaiting'] as int,
      severity: _severityFromString(json['severity'] as String),
      assignedBus: json['assignedBus'] as String?,
    );
  }

  final String id;
  final String name;
  final int studentsWaiting;
  final ZoneSeverity severity;
  final String? assignedBus;

  Zone toEntity() {
    return Zone(
      id: id,
      name: name,
      studentsWaiting: studentsWaiting,
      severity: severity,
      assignedBus: assignedBus,
    );
  }

  static ZoneSeverity _severityFromString(String value) {
    switch (value.toLowerCase()) {
      case 'critical':
        return ZoneSeverity.critical;
      case 'moderate':
        return ZoneSeverity.moderate;
      default:
        return ZoneSeverity.stable;
    }
  }
}
