import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/trip_booking_service.dart';
import '../providers/transit_provider.dart';
import '../providers/unified_auth_provider.dart';
import '../theme/app_theme.dart';

class PreBookingPanel extends StatefulWidget {
  const PreBookingPanel({super.key});

  @override
  State<PreBookingPanel> createState() => _PreBookingPanelState();
}

class _PreBookingPanelState extends State<PreBookingPanel> {
  final TripBookingService _service = TripBookingService();
  String? _selectedAreaId;

  String _normalizeAreaKey(String value) {
    return value.trim().toLowerCase();
  }

  String _formatDateTime(DateTime dateTime) {
    final DateTime local = dateTime.toLocal();
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    final String month = local.month.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  Map<String, dynamic> _bookingDataFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return doc.data();
  }

  @override
  Widget build(BuildContext context) {
    final UnifiedAuthProvider auth = context.watch<UnifiedAuthProvider>();
    final TransitProvider transit = context.watch<TransitProvider>();
    final String userId = auth.currentUser?.uid.trim() ?? '';
    final List<String> availableAreas = <String>{
      ...transit.pickupAreas.where((String item) => item.trim().isNotEmpty),
      if ((auth.defaultPickupArea ?? '').trim().isNotEmpty)
        auth.defaultPickupArea!.trim(),
      if (transit.selectedPickupArea.trim().isNotEmpty)
        transit.selectedPickupArea.trim(),
    }.toList(growable: false);

    final String preferredArea = (auth.defaultPickupArea ?? '').trim().isNotEmpty
        ? auth.defaultPickupArea!.trim()
        : (transit.selectedPickupArea.trim().isNotEmpty
            ? transit.selectedPickupArea.trim()
            : (availableAreas.isNotEmpty ? availableAreas.first : ''));

    final String areaId = availableAreas.contains(_selectedAreaId)
        ? _selectedAreaId!
        : preferredArea;

    if (_selectedAreaId != areaId && areaId.isNotEmpty) {
      _selectedAreaId = areaId;
    }

    final bool hasUser = userId.isNotEmpty;

    if (!hasUser) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF111D38).withValues(alpha: 0.76)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD9E5FF)),
        ),
        child: const Text(
          'سجل الدخول أولاً حتى تظهر لك الحجوزات المسبقة.',
        ),
      );
    }

    if (availableAreas.isEmpty || areaId.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF111D38).withValues(alpha: 0.76)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD9E5FF)),
        ),
        child: const Text(
          'لا توجد مناطق متاحة للحجز المسبق حالياً.',
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.watchTripSlotsForArea(areaId),
      builder: (
        BuildContext context,
        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> slotSnapshot,
      ) {
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> slotDocs =
            slotSnapshot.data?.docs ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> activeSlotDocs =
            slotDocs.where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          final Map<String, dynamic> slotData = doc.data();
          final String slotAreaId = (slotData['areaId'] ?? '').toString().trim();
          final String slotAreaKey = (slotData['areaKey'] ?? '').toString().trim();
          final bool areaMatch = slotAreaKey.isNotEmpty
              ? slotAreaKey == _normalizeAreaKey(areaId)
              : _normalizeAreaKey(slotAreaId) == _normalizeAreaKey(areaId);
          return areaMatch && slotData['active'] == true;
        }).toList()
              ..sort((QueryDocumentSnapshot<Map<String, dynamic>> a, QueryDocumentSnapshot<Map<String, dynamic>> b) {
                final DateTime? departureA = _toDateTime(a.data()['departureAt']);
                final DateTime? departureB = _toDateTime(b.data()['departureAt']);
                if (departureA == null && departureB == null) {
                  return a.id.compareTo(b.id);
                }
                if (departureA == null) {
                  return 1;
                }
                if (departureB == null) {
                  return -1;
                }
                return departureA.compareTo(departureB);
              });

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _service.watchUserBookings(userId: userId, areaId: areaId),
          builder: (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> bookingSnapshot,
          ) {
            final Map<String, Map<String, dynamic>> bookingsBySlotId =
                <String, Map<String, dynamic>>{};
            for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                in bookingSnapshot.data?.docs ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
              final Map<String, dynamic> bookingData = _bookingDataFromDoc(doc);
              final String slotId = (bookingData['tripSlotId'] ?? '').toString().trim();
              final String bookingAreaId = (bookingData['areaId'] ?? '').toString().trim();
              if (slotId.isEmpty || bookingAreaId != areaId) {
                continue;
              }
              bookingsBySlotId[slotId] = <String, dynamic>{
                ...bookingData,
                '_docId': doc.id,
              };
            }

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF111D38).withValues(alpha: 0.76)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD9E5FF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'حجز مسبق للترويحة',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textPrimary
                              : AppColors.lightTextPrimary,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'اختر المنطقة ثم اختر الوقت المتاح الذي أضافه الليدر.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: areaId,
                    items: availableAreas
                        .map(
                          (String area) => DropdownMenuItem<String>(
                            value: area,
                            child: Text(area),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return;
                      }
                      setState(() {
                        _selectedAreaId = value.trim();
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'المنطقة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'المنطقة: $areaId',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 14),
                  if (slotSnapshot.hasError)
                    const Text('تعذر تحميل مواعيد الحجز.')
                  else if (activeSlotDocs.isEmpty)
                    const Text('لا توجد مواعيد متاحة الآن لهذه المنطقة.')
                  else
                    Column(
                      children: activeSlotDocs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                        final Map<String, dynamic> slotData = doc.data();
                        final DateTime? departureAt = _toDateTime(slotData['departureAt']);
                        final int maxCapacity = _readInt(slotData['maxCapacity'], fallback: 0);
                        final int bookedCount = _readInt(slotData['bookedCount']);
                        final int remainingSeats = maxCapacity > 0
                            ? (maxCapacity - bookedCount).clamp(0, maxCapacity)
                            : 0;
                        final Map<String, dynamic>? existingBooking = bookingsBySlotId[doc.id];
                        final String currentStatus = (existingBooking?['status'] ?? '').toString().trim();
                        final bool canCancel =
                            existingBooking != null &&
                            currentStatus != 'activated' &&
                            currentStatus != 'cancelled';
                        final bool booked = existingBooking != null;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF132039),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF2D4061)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        departureAt == null
                                            ? 'موعد غير محدد'
                                            : _formatDateTime(departureAt),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                    if (booked)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: currentStatus == 'activated'
                                              ? const Color(0xFFDFF6E5)
                                              : const Color(0xFFFEE2E2),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          currentStatus == 'activated'
                                              ? 'مفعّل'
                                              : 'محجوز',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  maxCapacity > 0
                                      ? 'السعة: $bookedCount / $maxCapacity'
                                      : 'السعة: غير محددة',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.accentLight),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'المقاعد المتبقية: ${maxCapacity > 0 ? remainingSeats : 0}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.textSecondary),
                                ),
                                if (booked) ...<Widget>[
                                  const SizedBox(height: 10),
                                  Text(
                                    'لديك حجز مسبق لهذا الموعد.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.accentLight),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.event_seat_rounded),
                                        label: const Text('احجز الآن'),
                                        onPressed: booked || departureAt == null
                                            ? null
                                            : () async {
                                                final TripBookingResult validation =
                                                    await _service.validateBooking(
                                                  userId: userId,
                                                  areaId: areaId,
                                                  tripSlotId: doc.id,
                                                );
                                                if (!validation.success) {
                                                  if (!context.mounted) {
                                                    return;
                                                  }
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(validation.message),
                                                    ),
                                                  );
                                                  return;
                                                }

                                                final TripBookingResult result =
                                                    await _service.createBooking(
                                                  userId: userId,
                                                  areaId: areaId,
                                                  tripSlotId: doc.id,
                                                );

                                                if (!context.mounted) {
                                                  return;
                                                }

                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(result.message),
                                                  ),
                                                );
                                              },
                                      ),
                                    ),
                                    if (canCancel) ...<Widget>[
                                      const SizedBox(width: 10),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.cancel_outlined),
                                        label: const Text('إلغاء'),
                                        onPressed: () async {
                                          final TripBookingResult result =
                                              await _service.cancelBooking(
                                            userId: userId,
                                            tripSlotId: doc.id,
                                          );
                                          if (!context.mounted) {
                                            return;
                                          }
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(result.message),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(growable: false),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  DateTime? _toDateTime(dynamic value) {
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
}