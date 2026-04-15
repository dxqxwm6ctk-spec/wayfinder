import 'package:cloud_firestore/cloud_firestore.dart';

class TripBookingResult {
  const TripBookingResult({
    required this.success,
    required this.message,
    this.bookingId,
    this.status,
  });

  final bool success;
  final String message;
  final String? bookingId;
  final String? status;
}

class TripBookingService {
  TripBookingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTripSlotsForArea(
    String areaId,
  ) {
    final String normalizedArea = areaId.trim();
    if (normalizedArea.isEmpty) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    return _firestore
        .collection('tripSlots')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchUserBookings({
    required String userId,
    required String areaId,
  }) {
    final String normalizedUserId = userId.trim();
    final String normalizedArea = areaId.trim();
    if (normalizedUserId.isEmpty || normalizedArea.isEmpty) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    return _firestore
        .collection('preBookings')
      .where('userId', isEqualTo: normalizedUserId)
        .snapshots();
  }

  Future<TripBookingResult> validateBooking({
    required String userId,
    required String areaId,
    required String tripSlotId,
  }) async {
    try {
      final _TripSlotValidationState validationState =
          await _readValidationState(
        userId: userId,
        areaId: areaId,
        tripSlotId: tripSlotId,
      );

      if (!validationState.allowed) {
        return TripBookingResult(
          success: false,
          message: validationState.message,
          status: validationState.existingStatus,
        );
      }

      return const TripBookingResult(
        success: true,
        message: 'الرحلة جاهزة للحجز.',
        status: 'pending',
      );
    } catch (error) {
      return TripBookingResult(
        success: false,
        message: _friendlyErrorMessage(error),
      );
    }
  }

  Future<TripBookingResult> createBooking({
    required String userId,
    required String areaId,
    required String tripSlotId,
  }) async {
    final String normalizedUserId = userId.trim();
    final String normalizedArea = areaId.trim();
    final String normalizedSlotId = tripSlotId.trim();

    if (normalizedUserId.isEmpty ||
        normalizedArea.isEmpty ||
        normalizedSlotId.isEmpty) {
      return const TripBookingResult(
        success: false,
        message: 'بيانات الحجز غير مكتملة.',
      );
    }

    try {
      return await _firestore.runTransaction((transaction) async {
        final _TripSlotValidationState validationState =
            await _readValidationState(
          userId: normalizedUserId,
          areaId: normalizedArea,
          tripSlotId: normalizedSlotId,
          transaction: transaction,
        );

        if (!validationState.allowed) {
          return TripBookingResult(
            success: false,
            message: validationState.message,
            status: validationState.existingStatus,
          );
        }

        final DocumentReference<Map<String, dynamic>> slotRef = _firestore
            .collection('tripSlots')
            .doc(normalizedSlotId);
        final DocumentReference<Map<String, dynamic>> bookingRef = _firestore
            .collection('preBookings')
            .doc('${normalizedSlotId}_$normalizedUserId');

        final Map<String, dynamic> bookingData = <String, dynamic>{
          'userId': normalizedUserId,
          'areaId': normalizedArea,
          'tripSlotId': normalizedSlotId,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        transaction.set(bookingRef, bookingData);
        transaction.update(slotRef, <String, dynamic>{
          'bookedCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return TripBookingResult(
          success: true,
          message: 'تم حفظ الحجز المسبق.',
          bookingId: bookingRef.id,
          status: 'pending',
        );
      });
    } catch (error) {
      return TripBookingResult(
        success: false,
        message: _friendlyErrorMessage(error),
      );
    }
  }

  Future<TripBookingResult> cancelBooking({
    required String userId,
    required String tripSlotId,
  }) async {
    final String normalizedUserId = userId.trim();
    final String normalizedSlotId = tripSlotId.trim();

    if (normalizedUserId.isEmpty || normalizedSlotId.isEmpty) {
      return const TripBookingResult(
        success: false,
        message: 'بيانات الإلغاء غير مكتملة.',
      );
    }

    try {
      return await _firestore.runTransaction((transaction) async {
        final DocumentReference<Map<String, dynamic>> bookingRef = _firestore
            .collection('preBookings')
            .doc('${normalizedSlotId}_$normalizedUserId');
        final DocumentSnapshot<Map<String, dynamic>> bookingSnap =
            await transaction.get(bookingRef);

        if (!bookingSnap.exists) {
          return const TripBookingResult(
            success: false,
            message: 'الحجز غير موجود.',
          );
        }

        final Map<String, dynamic> bookingData = bookingSnap.data() ??
            <String, dynamic>{};
        final String currentStatus = (bookingData['status'] ?? '').toString().trim();
        if (currentStatus == 'activated') {
          return TripBookingResult(
            success: false,
            message: 'تم تفعيل الترويحة بالفعل ولا يمكن إلغاء الحجز الآن.',
          );
        }

        if (currentStatus == 'cancelled') {
          return TripBookingResult(
            success: true,
            message: 'الحجز ملغي مسبقًا.',
            bookingId: bookingRef.id,
            status: currentStatus,
          );
        }

        final DocumentReference<Map<String, dynamic>> slotRef = _firestore
            .collection('tripSlots')
            .doc(normalizedSlotId);
        final DocumentSnapshot<Map<String, dynamic>> slotSnap =
            await transaction.get(slotRef);

        if (slotSnap.exists) {
          final Map<String, dynamic> slotData = slotSnap.data() ??
              <String, dynamic>{};
          final int bookedCount = _readInt(slotData['bookedCount']);
          transaction.update(slotRef, <String, dynamic>{
            'bookedCount': bookedCount > 0 ? bookedCount - 1 : 0,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        transaction.update(bookingRef, <String, dynamic>{
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return TripBookingResult(
          success: true,
          message: 'تم إلغاء الحجز.',
          bookingId: bookingRef.id,
          status: 'cancelled',
        );
      });
    } catch (error) {
      return TripBookingResult(
        success: false,
        message: _friendlyErrorMessage(error),
      );
    }
  }

  Future<_TripSlotValidationState> _readValidationState({
    required String userId,
    required String areaId,
    required String tripSlotId,
    Transaction? transaction,
  }) async {
    final DocumentReference<Map<String, dynamic>> slotRef = _firestore
        .collection('tripSlots')
        .doc(tripSlotId.trim());
    final DocumentReference<Map<String, dynamic>> bookingRef = _firestore
        .collection('preBookings')
        .doc('${tripSlotId.trim()}_${userId.trim()}');

    final DocumentSnapshot<Map<String, dynamic>> slotSnap = transaction == null
        ? await slotRef.get()
        : await transaction.get(slotRef);

    if (!slotSnap.exists) {
      return const _TripSlotValidationState(
        allowed: false,
        message: 'الموعد غير موجود.',
      );
    }

    final Map<String, dynamic> slotData = slotSnap.data() ?? <String, dynamic>{};
    final String slotAreaId = (slotData['areaId'] ?? '').toString().trim();
    if (slotAreaId.isEmpty || _normalize(slotAreaId) != _normalize(areaId)) {
      return const _TripSlotValidationState(
        allowed: false,
        message: 'هذا الموعد غير متاح لمنطقتك.',
      );
    }

    if (slotData['active'] != true) {
      return const _TripSlotValidationState(
        allowed: false,
        message: 'الموعد غير فعال حالياً.',
      );
    }

    final DateTime? departureAt = _readDepartureAt(slotData['departureAt']);
    if (departureAt == null) {
      return const _TripSlotValidationState(
        allowed: false,
        message: 'الموعد يفتقد وقت الانطلاق.',
      );
    }

    final int cutoffMinutes = _readInt(slotData['cutoffMinutes'], fallback: 30);
    final DateTime cutoffAt = departureAt.subtract(
      Duration(minutes: cutoffMinutes > 0 ? cutoffMinutes : 30),
    );
    if (DateTime.now().isAfter(cutoffAt)) {
      return const _TripSlotValidationState(
        allowed: false,
        message: 'انتهى وقت الحجز لهذا الموعد.',
      );
    }

    final int maxCapacity = _readInt(slotData['maxCapacity'], fallback: 0);
    final int bookedCount = _readInt(slotData['bookedCount']);
    if (maxCapacity > 0 && bookedCount >= maxCapacity) {
      return const _TripSlotValidationState(
        allowed: false,
        message: 'هذا الموعد ممتلئ.',
      );
    }

    final DocumentSnapshot<Map<String, dynamic>> bookingSnap = transaction == null
        ? await bookingRef.get()
        : await transaction.get(bookingRef);
    if (bookingSnap.exists) {
      final Map<String, dynamic> bookingData = bookingSnap.data() ??
          <String, dynamic>{};
      final String currentStatus = (bookingData['status'] ?? '').toString().trim();
      if (currentStatus.isNotEmpty &&
          currentStatus != 'cancelled' &&
          currentStatus != 'rejected') {
        return _TripSlotValidationState(
          allowed: false,
          message: 'لديك حجز مسبق لنفس الموعد.',
          existingStatus: currentStatus,
        );
      }
    }

    return _TripSlotValidationState(
      allowed: true,
      message: 'الحجز متاح.',
      departureAt: departureAt,
      cutoffAt: cutoffAt,
    );
  }

  DateTime? _readDepartureAt(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  int _readInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    return fallback;
  }

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  String _friendlyErrorMessage(Object error) {
    final String text = error.toString();
    if (text.contains('permission-denied')) {
      return 'لا تملك صلاحية تنفيذ هذا الإجراء.';
    }
    if (text.contains('already-exists')) {
      return 'لديك حجز موجود مسبقًا.';
    }
    return 'تعذر تنفيذ العملية الآن. حاول مرة أخرى.';
  }
}

class _TripSlotValidationState {
  const _TripSlotValidationState({
    required this.allowed,
    required this.message,
    this.existingStatus,
    this.departureAt,
    this.cutoffAt,
  });

  final bool allowed;
  final String message;
  final String? existingStatus;
  final DateTime? departureAt;
  final DateTime? cutoffAt;
}