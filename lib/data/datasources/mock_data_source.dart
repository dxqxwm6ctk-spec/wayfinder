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
  "waitingStudents": 14,
  "fleetStatus": "BUS #12 READY",
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
    {"id": "1", "name": "الجبل الشمالي", "studentsWaiting": 8, "severity": "moderate", "assignedBus": "B01"},
    {"id": "2", "name": "جبل الحسين", "studentsWaiting": 12, "severity": "critical", "assignedBus": "B02"},
    {"id": "3", "name": "الجاردنز", "studentsWaiting": 5, "severity": "stable", "assignedBus": null},
    {"id": "4", "name": "الزهور", "studentsWaiting": 15, "severity": "critical", "assignedBus": "B03"},
    {"id": "5", "name": "القويسمة", "studentsWaiting": 7, "severity": "moderate", "assignedBus": null},
    {"id": "6", "name": "أبو علندا", "studentsWaiting": 3, "severity": "stable", "assignedBus": null},
    {"id": "7", "name": "النزهة", "studentsWaiting": 9, "severity": "moderate", "assignedBus": "B04"},
    {"id": "8", "name": "طبربور", "studentsWaiting": 11, "severity": "critical", "assignedBus": "B05"},
    {"id": "9", "name": "المقابلين", "studentsWaiting": 4, "severity": "stable", "assignedBus": null},
    {"id": "10", "name": "البيادر", "studentsWaiting": 6, "severity": "moderate", "assignedBus": null},
    {"id": "11", "name": "سحاب", "studentsWaiting": 10, "severity": "critical", "assignedBus": "B06"},
    {"id": "12", "name": "الوحدات", "studentsWaiting": 8, "severity": "moderate", "assignedBus": null},
    {"id": "13", "name": "الشرق الأوسط", "studentsWaiting": 14, "severity": "critical", "assignedBus": "B07"},
    {"id": "14", "name": "أبو نصير", "studentsWaiting": 5, "severity": "stable", "assignedBus": null},
    {"id": "15", "name": "ناعور", "studentsWaiting": 9, "severity": "moderate", "assignedBus": "B08"},
    {"id": "16", "name": "الكرك", "studentsWaiting": 2, "severity": "stable", "assignedBus": null},
    {"id": "17", "name": "السلط", "studentsWaiting": 11, "severity": "critical", "assignedBus": "B09"},
    {"id": "18", "name": "لواء الجيزة", "studentsWaiting": 7, "severity": "moderate", "assignedBus": null},
    {"id": "19", "name": "رغدان", "studentsWaiting": 13, "severity": "critical", "assignedBus": "B10"},
    {"id": "20", "name": "الصويفية", "studentsWaiting": 6, "severity": "stable", "assignedBus": null},
    {"id": "21", "name": "صويلح", "studentsWaiting": 8, "severity": "moderate", "assignedBus": "B11"},
    {"id": "22", "name": "شارع الجامعة", "studentsWaiting": 10, "severity": "critical", "assignedBus": "B12"},
    {"id": "23", "name": "نزال", "studentsWaiting": 4, "severity": "stable", "assignedBus": null},
    {"id": "24", "name": "مادبا", "studentsWaiting": 7, "severity": "moderate", "assignedBus": "B13"},
    {"id": "25", "name": "مرج الحمام", "studentsWaiting": 12, "severity": "critical", "assignedBus": "B14"},
    {"id": "26", "name": "الزرقاء", "studentsWaiting": 5, "severity": "stable", "assignedBus": null},
    {"id": "27", "name": "الرصيفة", "studentsWaiting": 9, "severity": "moderate", "assignedBus": "B15"}
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
