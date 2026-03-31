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
    "North Campus (Library Hub)",
    "STEM Plaza",
    "South Terminal",
    "Housing Complex"
  ],
  "zones": [
    {
      "id": "north",
      "name": "North Campus",
      "studentsWaiting": 25,
      "severity": "critical",
      "assignedBus": "B42"
    },
    {
      "id": "stem",
      "name": "STEM Plaza",
      "studentsWaiting": 14,
      "severity": "moderate",
      "assignedBus": null
    },
    {
      "id": "south",
      "name": "South Terminal",
      "studentsWaiting": 8,
      "severity": "stable",
      "assignedBus": null
    }
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
