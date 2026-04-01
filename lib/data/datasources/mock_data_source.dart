import 'dart:convert';

import '../models/zone_model.dart';

class MockDataSource {
  Future<Map<String, dynamic>> fetchDashboard() async {
    await Future.delayed(const Duration(milliseconds: 280));
    return jsonDecode(_dashboardJson) as Map<String, dynamic>;
  }

  static const String _dashboardJson = '''
{
  "systemStatus": "System Live",
  "campusConnectivity": "98% Uptime",
  "waitingStudents": 0,
  "fleetStatus": "NO BUS ASSIGNED",
  "pickupAreas": [
    "الجبل الشمالي",
    "جبل الحسين",
    "الجاردنز",
    "الزهور",
    "القويسمة",
    "أبو علندا",
    "النزهة",
    "طبربور",
    "المقابلين",
    "البيادر",
    "سحاب",
    "الوحدات",
    "الشرق الأوسط",
    "أبو نصير",
    "ناعور",
    "الكرك",
    "السلط",
    "لواء الجيزة",
    "رغدان",
    "الصويفية",
    "صويلح",
    "شارع الجامعة",
    "نزال",
    "مادبا",
    "مرج الحمام",
    "الزرقاء",
    "الرصيفة"
  ],
  "zones": [
    {"id": "1", "name": "الجبل الشمالي", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "2", "name": "جبل الحسين", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "3", "name": "الجاردنز", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "4", "name": "الزهور", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "5", "name": "القويسمة", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "6", "name": "أبو علندا", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "7", "name": "النزهة", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "8", "name": "طبربور", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "9", "name": "المقابلين", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "10", "name": "البيادر", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "11", "name": "سحاب", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "12", "name": "الوحدات", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "13", "name": "الشرق الأوسط", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "14", "name": "أبو نصير", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "15", "name": "ناعور", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "16", "name": "الكرك", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "17", "name": "السلط", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "18", "name": "لواء الجيزة", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "19", "name": "رغدان", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "20", "name": "الصويفية", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "21", "name": "صويلح", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "22", "name": "شارع الجامعة", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "23", "name": "نزال", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "24", "name": "مادبا", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "25", "name": "مرج الحمام", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "26", "name": "الزرقاء", "studentsWaiting": 0, "severity": "stable", "assignedBus": null},
    {"id": "27", "name": "الرصيفة", "studentsWaiting": 0, "severity": "stable", "assignedBus": null}
  ]
}
''';

  List<ZoneModel> parseZones(Map<String, dynamic> json) {
    final List<dynamic> zoneList = json['zones'] as List<dynamic>;
    return zoneList
        .map((dynamic item) => ZoneModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
