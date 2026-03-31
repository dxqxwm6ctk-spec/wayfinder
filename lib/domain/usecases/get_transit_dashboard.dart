import '../entities/zone.dart';
import '../repositories/transit_repository.dart';

class TransitDashboardData {
  const TransitDashboardData({
    required this.waitingStudents,
    required this.fleetStatus,
    required this.pickupAreas,
    required this.systemStatus,
    required this.campusConnectivity,
    required this.zones,
  });

  final int waitingStudents;
  final String fleetStatus;
  final List<String> pickupAreas;
  final String systemStatus;
  final String campusConnectivity;
  final List<Zone> zones;
}

class GetTransitDashboard {
  GetTransitDashboard(this._repository);

  final TransitRepository _repository;

  Future<TransitDashboardData> call() async {
    final results = await Future.wait<dynamic>([
      _repository.getWaitingStudents(),
      _repository.getFleetStatus(),
      _repository.getPickupAreas(),
      _repository.getSystemStatus(),
      _repository.getCampusConnectivity(),
      _repository.getZones(),
    ]);

    return TransitDashboardData(
      waitingStudents: results[0] as int,
      fleetStatus: results[1] as String,
      pickupAreas: results[2] as List<String>,
      systemStatus: results[3] as String,
      campusConnectivity: results[4] as String,
      zones: results[5] as List<Zone>,
    );
  }
}
