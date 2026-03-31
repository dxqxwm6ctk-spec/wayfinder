import '../../domain/entities/zone.dart';
import '../../domain/repositories/transit_repository.dart';
import '../datasources/mock_data_source.dart';
import '../datasources/remote/remote_api_data_source.dart';

class TransitRepositoryImpl implements TransitRepository {
  TransitRepositoryImpl(this._mockDataSource, {this.remoteApiDataSource});

  final MockDataSource _mockDataSource;
  final RemoteApiDataSource? remoteApiDataSource;

  Future<Map<String, dynamic>> _dashboardJson() async {
    if (remoteApiDataSource != null) {
      try {
        return await remoteApiDataSource!.fetchDashboard();
      } catch (_) {
        // Fallback to mock data if remote endpoint fails.
      }
    }
    return _mockDataSource.fetchDashboard();
  }

  @override
  Future<String> getCampusConnectivity() async {
    final Map<String, dynamic> json = await _dashboardJson();
    return json['campusConnectivity'] as String;
  }

  @override
  Future<String> getFleetStatus() async {
    final Map<String, dynamic> json = await _dashboardJson();
    return json['fleetStatus'] as String;
  }

  @override
  Future<List<String>> getPickupAreas() async {
    final Map<String, dynamic> json = await _dashboardJson();
    final List<dynamic> rawList = json['pickupAreas'] as List<dynamic>;
    return rawList.cast<String>();
  }

  @override
  Future<String> getSystemStatus() async {
    final Map<String, dynamic> json = await _dashboardJson();
    return json['systemStatus'] as String;
  }

  @override
  Future<int> getWaitingStudents() async {
    final Map<String, dynamic> json = await _dashboardJson();
    return json['waitingStudents'] as int;
  }

  @override
  Future<List<Zone>> getZones() async {
    final Map<String, dynamic> json = await _dashboardJson();
    return _mockDataSource.parseZones(json).map((zone) => zone.toEntity()).toList();
  }
}
