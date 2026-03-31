enum ZoneSeverity { critical, moderate, stable }

class Zone {
  const Zone({
    required this.id,
    required this.name,
    required this.studentsWaiting,
    required this.severity,
    this.assignedBus,
  });

  final String id;
  final String name;
  final int studentsWaiting;
  final ZoneSeverity severity;
  final String? assignedBus;

  Zone copyWith({
    String? id,
    String? name,
    int? studentsWaiting,
    ZoneSeverity? severity,
    String? assignedBus,
    bool clearAssignedBus = false,
  }) {
    return Zone(
      id: id ?? this.id,
      name: name ?? this.name,
      studentsWaiting: studentsWaiting ?? this.studentsWaiting,
      severity: severity ?? this.severity,
      assignedBus: clearAssignedBus ? null : (assignedBus ?? this.assignedBus),
    );
  }
}
