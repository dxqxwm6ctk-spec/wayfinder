import 'package:flutter/foundation.dart';

import '../../domain/entities/zone.dart';
import '../../domain/usecases/get_transit_dashboard.dart';

class RequestExecutionSummary {
  const RequestExecutionSummary({
    required this.area,
    required this.studentsWaiting,
    required this.busNumber,
  });

  final String area;
  final int studentsWaiting;
  final String? busNumber;
}

class TransitProvider extends ChangeNotifier {
  TransitProvider(this._getTransitDashboard);

  final GetTransitDashboard _getTransitDashboard;

  bool _loading = false;
  bool _hasLoaded = false;
  int _waitingStudents = 0;
  String _fleetStatus = 'BUS #12 READY';
  String _systemStatus = 'System Live';
  String _campusConnectivity = '98% Uptime';
  bool _immediatePickup = true;
  List<String> _pickupAreas = <String>[];
  String _selectedPickupArea = '';
  List<Zone> _zones = <Zone>[];

  bool get loading => _loading;
  int get waitingStudents => _waitingStudents;
  String get fleetStatus {
    final Zone? zone = _zoneByPickupArea(_selectedPickupArea);
    if (zone?.assignedBus != null && zone!.assignedBus!.isNotEmpty) {
      return 'BUS #${zone.assignedBus!.toUpperCase()} READY';
    }
    return _fleetStatus;
  }
  String get systemStatus => _systemStatus;
  String get campusConnectivity => _campusConnectivity;
  bool get immediatePickup => _immediatePickup;
  List<String> get pickupAreas => _pickupAreas;
  String get selectedPickupArea => _selectedPickupArea;
  List<Zone> get zones => _zones;

  Future<void> load({bool force = false}) async {
    if (_hasLoaded && !force) {
      return;
    }

    _loading = true;
    notifyListeners();

    final TransitDashboardData dashboard = await _getTransitDashboard();
    _waitingStudents = dashboard.waitingStudents;
    _fleetStatus = dashboard.fleetStatus;
    _pickupAreas = dashboard.pickupAreas;
    _selectedPickupArea = dashboard.pickupAreas.first;
    _systemStatus = dashboard.systemStatus;
    _campusConnectivity = dashboard.campusConnectivity;
    _zones = dashboard.zones;
    _hasLoaded = true;

    _loading = false;
    notifyListeners();
  }

  void toggleImmediatePickup(bool value) {
    _immediatePickup = value;
    notifyListeners();
  }

  void selectPickupArea(String value) {
    _selectedPickupArea = value;
    notifyListeners();
  }

  void assignBus(String zoneId, String busNumber) {
    final String normalizedBus = busNumber.toUpperCase().replaceAll('BUS #', '').trim();
    _zones = _zones
        .map((Zone zone) => zone.id == zoneId
        ? zone.copyWith(assignedBus: normalizedBus)
            : zone)
        .toList();
    notifyListeners();
  }

  void removeBus(String zoneId) {
    _zones = _zones
        .map((Zone zone) => zone.id == zoneId
            ? zone.copyWith(clearAssignedBus: true)
            : zone)
        .toList();
    notifyListeners();
  }

  RequestExecutionSummary executeImmediateRequest() {
    final Zone? zone = _zoneByPickupArea(_selectedPickupArea);

    if (zone != null) {
      _zones = _zones
          .map(
            (Zone item) => item.id == zone.id
                ? item.copyWith(studentsWaiting: item.studentsWaiting + 1)
                : item,
          )
          .toList();
      _waitingStudents += 1;
      notifyListeners();

      final Zone updatedZone = _zones.firstWhere((Zone item) => item.id == zone.id);
      return RequestExecutionSummary(
        area: _selectedPickupArea,
        studentsWaiting: updatedZone.studentsWaiting,
        busNumber: updatedZone.assignedBus,
      );
    }

    _waitingStudents += 1;
    notifyListeners();

    return RequestExecutionSummary(
      area: _selectedPickupArea,
      studentsWaiting: _waitingStudents,
      busNumber: null,
    );
  }

  RequestExecutionSummary? cancelRequestForArea(String area) {
    final Zone? zone = _zoneByPickupArea(area);

    if (zone != null) {
      if (zone.studentsWaiting <= 0) {
        return null;
      }

      _zones = _zones
          .map(
            (Zone item) => item.id == zone.id
                ? item.copyWith(studentsWaiting: item.studentsWaiting - 1)
                : item,
          )
          .toList();

      if (_waitingStudents > 0) {
        _waitingStudents -= 1;
      }
      notifyListeners();

      final Zone updatedZone = _zones.firstWhere((Zone item) => item.id == zone.id);
      return RequestExecutionSummary(
        area: area,
        studentsWaiting: updatedZone.studentsWaiting,
        busNumber: updatedZone.assignedBus,
      );
    }

    if (_waitingStudents <= 0) {
      return null;
    }

    _waitingStudents -= 1;
    notifyListeners();
    return RequestExecutionSummary(
      area: area,
      studentsWaiting: _waitingStudents,
      busNumber: null,
    );
  }

  String? assignedBusForArea(String area) {
    final Zone? zone = _zoneByPickupArea(area);
    final String? bus = zone?.assignedBus?.trim();
    if (bus == null || bus.isEmpty) {
      return null;
    }
    return bus;
  }

  Zone? _zoneByPickupArea(String area) {
    final String normalizedArea = _normalize(area);
    return _firstWhereOrNull(
      (Zone zone) =>
          _normalize(zone.name) == normalizedArea ||
          _normalize(zone.id) == normalizedArea,
    );
  }

  String _normalize(String input) {
    return input.trim().toLowerCase();
  }

  Zone? _firstWhereOrNull(bool Function(Zone zone) predicate) {
    for (final Zone zone in _zones) {
      if (predicate(zone)) {
        return zone;
      }
    }
    return null;
  }
}
