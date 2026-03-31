import '../entities/zone.dart';

abstract class TransitRepository {
  Future<List<Zone>> getZones();
  Future<int> getWaitingStudents();
  Future<String> getFleetStatus();
  Future<List<String>> getPickupAreas();
  Future<String> getSystemStatus();
  Future<String> getCampusConnectivity();
}
