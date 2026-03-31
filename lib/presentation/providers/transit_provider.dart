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
  final Set<String> _departedZoneIds = <String>{};
  final Map<String, int> _boardedStudentsByZone = <String, int>{};
  bool _hasActiveStudentRequest = false;
  String? _activeRequestArea;
  DateTime? _lastUpdatedAt;

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
  bool get hasActiveStudentRequest => _hasActiveStudentRequest;
  String? get activeRequestArea => _activeRequestArea;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  Map<String, int> get boardedStudentsByZone =>
      Map<String, int>.unmodifiable(_boardedStudentsByZone);

  String get studentCurrentArea {
    if (_hasActiveStudentRequest && _activeRequestArea != null) {
      return _activeRequestArea!;
    }
    return _selectedPickupArea;
  }

  String? get busForStudentArea {
    final Zone? zone = _zoneByPickupArea(studentCurrentArea);
    final String? bus = zone?.assignedBus?.trim();
    if (bus == null || bus.isEmpty) {
      return null;
    }
    return bus;
  }

  bool get shouldPromptStudentBoarding {
    if (!_hasActiveStudentRequest || _activeRequestArea == null) {
      return false;
    }
    final Zone? zone = _zoneByPickupArea(_activeRequestArea!);
    if (zone == null) {
      return false;
    }
    return isBusDeparted(zone.id) &&
        zone.assignedBus != null &&
        zone.assignedBus!.trim().isNotEmpty;
  }

  int? get estimatedArrivalMinutesForStudentArea {
    final Zone? zone = _zoneByPickupArea(studentCurrentArea);
    if (zone == null || zone.assignedBus == null || zone.assignedBus!.trim().isEmpty) {
      return null;
    }

    // Simple ETA heuristic based on queue load for the zone.
    final int eta = 4 + ((zone.studentsWaiting / 3).ceil() * 2);
    if (eta < 4) {
      return 4;
    }
    if (eta > 30) {
      return 30;
    }
    return eta;
  }

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
    _selectedPickupArea = dashboard.pickupAreas.isNotEmpty
      ? dashboard.pickupAreas.first
      : '';
    _systemStatus = dashboard.systemStatus;
    _campusConnectivity = dashboard.campusConnectivity;
    _zones = dashboard.zones;
    _hasLoaded = true;
    _touchUpdatedAt();

    _loading = false;
    notifyListeners();
  }

  void toggleImmediatePickup(bool value) {
    _immediatePickup = value;
    _touchUpdatedAt();
    notifyListeners();
  }

  void selectPickupArea(String value) {
    _selectedPickupArea = value;
    _touchUpdatedAt();
    notifyListeners();
  }

  void assignBus(String zoneId, String busNumber) {
    final String normalizedBus = busNumber.toUpperCase().replaceAll('BUS #', '').trim();
    _zones = _zones
        .map((Zone zone) => zone.id == zoneId
        ? zone.copyWith(assignedBus: normalizedBus)
            : zone)
        .toList();
    _departedZoneIds.remove(zoneId);
    _touchUpdatedAt();
    notifyListeners();
  }

  void removeBus(String zoneId) {
    _zones = _zones
        .map((Zone zone) => zone.id == zoneId
            ? zone.copyWith(clearAssignedBus: true)
            : zone)
        .toList();
    _departedZoneIds.remove(zoneId);
    _touchUpdatedAt();
    notifyListeners();
  }

  void markBusDeparted(String zoneId) {
    final Zone? zone = _firstWhereOrNull((Zone z) => z.id == zoneId);
    if (zone == null || zone.assignedBus == null || zone.assignedBus!.trim().isEmpty) {
      return;
    }
    _departedZoneIds.add(zoneId);
    _touchUpdatedAt();
    notifyListeners();
  }

  bool isBusDeparted(String zoneId) {
    return _departedZoneIds.contains(zoneId);
  }

  RequestExecutionSummary executeImmediateRequest() {
    final Zone? zone = _zoneByPickupArea(_selectedPickupArea);

    if (!_hasActiveStudentRequest && zone != null) {
      _zones = _zones
          .map(
            (Zone item) => item.id == zone.id
                ? item.copyWith(studentsWaiting: item.studentsWaiting + 1)
                : item,
          )
          .toList();
      _waitingStudents += 1;
    }

    _hasActiveStudentRequest = true;
    _activeRequestArea = _selectedPickupArea;
    _touchUpdatedAt();
    notifyListeners();

    final Zone? updatedZone = _zoneByPickupArea(_selectedPickupArea);
    return RequestExecutionSummary(
      area: _selectedPickupArea,
      studentsWaiting: updatedZone?.studentsWaiting ?? _waitingStudents,
      busNumber: updatedZone?.assignedBus,
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

      if (_hasActiveStudentRequest && _activeRequestArea == area) {
        _hasActiveStudentRequest = false;
        _activeRequestArea = null;
      }

      _touchUpdatedAt();
      notifyListeners();

      final Zone? updatedZone = _zoneByPickupArea(area);
      return RequestExecutionSummary(
        area: area,
        studentsWaiting: updatedZone?.studentsWaiting ?? 0,
        busNumber: updatedZone?.assignedBus,
      );
    }

    if (_waitingStudents <= 0) {
      return null;
    }

    _waitingStudents -= 1;
    if (_hasActiveStudentRequest && _activeRequestArea == area) {
      _hasActiveStudentRequest = false;
      _activeRequestArea = null;
    }
    _touchUpdatedAt();
    notifyListeners();
    return RequestExecutionSummary(
      area: area,
      studentsWaiting: _waitingStudents,
      busNumber: null,
    );
  }

  bool markCurrentStudentBoarded() {
    if (!_hasActiveStudentRequest || _activeRequestArea == null) {
      return false;
    }

    final Zone? zone = _zoneByPickupArea(_activeRequestArea!);
    if (zone == null || !isBusDeparted(zone.id) || zone.studentsWaiting <= 0) {
      return false;
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

    _boardedStudentsByZone[zone.id] =
        (_boardedStudentsByZone[zone.id] ?? 0) + 1;

    _hasActiveStudentRequest = false;
    _activeRequestArea = null;
    _touchUpdatedAt();
    notifyListeners();
    return true;
  }

  int leaderMarkStudentsBoarded(String zoneId, int count) {
    final Zone? zone = _firstWhereOrNull((Zone z) => z.id == zoneId);
    if (zone == null || zone.studentsWaiting <= 0 || count <= 0) {
      return 0;
    }

    final int applied = count > zone.studentsWaiting
        ? zone.studentsWaiting
        : count;

    _zones = _zones
        .map(
          (Zone item) => item.id == zoneId
              ? item.copyWith(studentsWaiting: item.studentsWaiting - applied)
              : item,
        )
        .toList();

    _waitingStudents = (_waitingStudents - applied).clamp(0, _waitingStudents);

    _boardedStudentsByZone[zoneId] =
        (_boardedStudentsByZone[zoneId] ?? 0) + applied;

    _touchUpdatedAt();
    notifyListeners();
    return applied;
  }

  int boardedCountForZone(String zoneId) {
    return _boardedStudentsByZone[zoneId] ?? 0;
  }

  int waitingCountForZone(String zoneId) {
    final Zone? zone = _firstWhereOrNull((Zone z) => z.id == zoneId);
    return zone?.studentsWaiting ?? 0;
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

  void _touchUpdatedAt() {
    _lastUpdatedAt = DateTime.now();
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
