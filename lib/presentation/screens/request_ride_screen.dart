import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_strings.dart';
import '../providers/app_settings_provider.dart';
import '../widgets/pre_booking_panel.dart';
import '../providers/transit_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell_background.dart';
import '../widgets/custom_button.dart';
import '../widgets/header_row.dart';
import '../widgets/info_card.dart';

class RequestRideScreen extends StatefulWidget {
  const RequestRideScreen({super.key});

  @override
  State<RequestRideScreen> createState() => _RequestRideScreenState();
}

class _RequestRideScreenState extends State<RequestRideScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _requestFirestore = FirebaseFirestore.instance;

  RequestExecutionSummary? _lastSummary;
  String? _lastBusAssignmentNotificationKey;
  String? _lastDepartedPromptKey;
  String? _lastRideCancelledNotificationKey;
  String? _queueStudentsSignature;
  Future<List<_QueueStudentInfo>>? _queueStudentsFuture;
  List<_QueueStudentInfo> _cachedQueueStudents = const <_QueueStudentInfo>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<TransitProvider>().load();
    });
  }

  bool _toBool(dynamic raw) {
    if (raw is bool) {
      return raw;
    }
    if (raw is num) {
      return raw != 0;
    }
    if (raw is String) {
      final String value = raw.trim().toLowerCase();
      return value == 'true' || value == '1';
    }
    return false;
  }

  RequestExecutionSummary? _summaryFromPersistedRequest(
    TransitProvider transit,
    Map<String, dynamic>? requestData,
  ) {
    if (requestData == null || requestData.isEmpty) {
      return null;
    }

    final bool hasActiveRequest = _toBool(requestData['hasActiveRequest']);
    if (!hasActiveRequest) {
      return null;
    }

    String area = (requestData['activeRequestArea'] as String? ?? '').trim();
    if (area.isEmpty) {
      area = (requestData['pickupArea'] as String? ?? '').trim();
    }
    if (area.isEmpty) {
      return null;
    }

    final int waitingStudents = transit.waitingStudentsForArea(area);
    return RequestExecutionSummary(
      area: area,
      studentsWaiting: waitingStudents,
      busNumber: transit.assignedBusForArea(area),
    );
  }

  Widget _buildQueueSnapshotCard({
    required BuildContext context,
    required AppStrings strings,
    required TransitProvider transit,
    required RequestExecutionSummary summary,
    required bool isDark,
  }) {
    final String? zoneId = _resolveZoneIdForArea(transit, summary.area);
    final bool hasBus =
        summary.busNumber != null && summary.busNumber!.trim().isNotEmpty;

    if (zoneId == null) {
      return _queueSnapshotCardBody(
        context: context,
        strings: strings,
        isDark: isDark,
        hasBus: hasBus,
        summary: summary,
        waitingCount: summary.studentsWaiting,
        students: const <_QueueStudentInfo>[],
        fallbackLabel: strings.studentFallback,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('studentRequests')
          .where('zoneId', isEqualTo: zoneId)
          .where('status', isEqualTo: 'pending')
          .limit(30)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> requestSnapshot,
          ) {
            final List<QueryDocumentSnapshot<Map<String, dynamic>>>
            requestDocs =
                requestSnapshot.data?.docs ??
                const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final String signature = requestDocs
                .map(
                  (QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id,
                )
                .join('|');

            if (_queueStudentsSignature != signature ||
                _queueStudentsFuture == null) {
              _queueStudentsSignature = signature;
              _queueStudentsFuture = _loadQueueStudents(requestDocs).then((
                List<_QueueStudentInfo> students,
              ) {
                if (mounted) {
                  setState(() {
                    _cachedQueueStudents = students;
                  });
                } else {
                  _cachedQueueStudents = students;
                }
                return students;
              });
            }

            return FutureBuilder<List<_QueueStudentInfo>>(
              future: _queueStudentsFuture,
              initialData: _cachedQueueStudents,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<_QueueStudentInfo>> studentSnapshot,
                  ) {
                    final List<_QueueStudentInfo> students =
                        studentSnapshot.data ?? const <_QueueStudentInfo>[];
                    return _queueSnapshotCardBody(
                      context: context,
                      strings: strings,
                      isDark: isDark,
                      hasBus: hasBus,
                      summary: summary,
                      waitingCount: summary.studentsWaiting,
                      students: students,
                      fallbackLabel: strings.studentFallback,
                    );
                  },
            );
          },
    );
  }

  Widget _queueSnapshotCardBody({
    required BuildContext context,
    required AppStrings strings,
    required bool isDark,
    required bool hasBus,
    required RequestExecutionSummary summary,
    required int waitingCount,
    required List<_QueueStudentInfo> students,
    required String fallbackLabel,
  }) {
    final List<_QueueStudentInfo> avatarStudents = students
        .take(3)
        .toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF111D38).withValues(alpha: 0.78)
            : const Color(0xFFF9FBFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFD9E5FF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _buildAvatarStack(
                context: context,
                isDark: isDark,
                waitingCount: waitingCount,
                students: avatarStudents,
                fallbackLabel: fallbackLabel,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      strings.studentsWaitingCount(waitingCount),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: hasBus
                            ? const Color(0xFFDFF6E5)
                            : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            hasBus
                                ? Icons.check_circle_rounded
                                : Icons.info_rounded,
                            size: 16,
                            color: hasBus
                                ? const Color(0xFF137A40)
                                : const Color(0xFFB42318),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasBus
                                ? 'BUS #${summary.busNumber} ${strings.available}'
                                : strings.noBusAssigned,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                  color: hasBus
                                      ? const Color(0xFF137A40)
                                      : const Color(0xFFB42318),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarStack({
    required BuildContext context,
    required bool isDark,
    required int waitingCount,
    required List<_QueueStudentInfo> students,
    required String fallbackLabel,
  }) {
    final List<Color> avatarColors = <Color>[
      const Color(0xFFFFDCC8),
      const Color(0xFFCAE6FF),
      const Color(0xFFD7F6D6),
      const Color(0xFFE7DAFF),
    ];

    final int avatarCount = waitingCount > 3 ? 3 : students.length.clamp(0, 3);
    final bool showOverflowBadge = waitingCount > 3;
    final int overflowCount = (waitingCount - 3).clamp(0, 999);
    final double stackWidth = avatarCount <= 0
        ? 0
        : 44 + ((avatarCount - 1) * 24) + (showOverflowBadge ? 44 : 0);

    return SizedBox(
      width: stackWidth,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          for (int i = 0; i < avatarCount; i++)
            Positioned(
              left: i * 24,
              child: _buildStudentAvatar(
                context: context,
                isDark: isDark,
                fallbackColor: avatarColors[i % avatarColors.length],
                student: i < students.length ? students[i] : null,
                fallbackLabel: fallbackLabel,
              ),
            ),
          if (showOverflowBadge)
            Positioned(
              left: avatarCount * 24,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFBFD9FF),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF111D38) : Colors.white,
                    width: 2.4,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$overflowCount+',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF253866),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStudentAvatar({
    required BuildContext context,
    required bool isDark,
    required Color fallbackColor,
    required _QueueStudentInfo? student,
    required String fallbackLabel,
  }) {
    final String displayName = student?.name.trim() ?? '';
    final String initial = displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : (fallbackLabel.isNotEmpty
              ? fallbackLabel.substring(0, 1).toUpperCase()
              : 'S');
    final String? photoUrl = _normalizeImageUrl(student?.photoUrl);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: fallbackColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? const Color(0xFF111D38) : Colors.white,
          width: 2.4,
        ),
      ),
      child: ClipOval(
        child: photoUrl != null && photoUrl.isNotEmpty
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.person_rounded,
                        size: 20,
                        color: Color(0xFF1F2937),
                      ),
                      Text(
                        initial,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF1F2937),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.person_rounded,
                      size: 20,
                      color: Color(0xFF1F2937),
                    ),
                    Text(
                      initial,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF1F2937),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  String? _resolveZoneIdForArea(TransitProvider transit, String area) {
    final String normalizedArea = area.trim().toLowerCase();
    for (final zone in transit.zones) {
      if (zone.name.trim().toLowerCase() == normalizedArea ||
          zone.id.trim().toLowerCase() == normalizedArea) {
        return zone.id;
      }
    }
    return null;
  }

  Future<List<_QueueStudentInfo>> _loadQueueStudents(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> requestDocs,
  ) async {
    if (requestDocs.isEmpty) {
      return const <_QueueStudentInfo>[];
    }

    final List<_QueueStudentInfo> students = <_QueueStudentInfo>[];
    final Set<String> seen = <String>{};

    for (final QueryDocumentSnapshot<Map<String, dynamic>> requestDoc
        in requestDocs) {
      final Map<String, dynamic> requestData = requestDoc.data();
      final String studentKey =
          _readFirstString(requestData, <String>[
            'studentId',
            'studentUid',
            'userId',
            'uid',
            'email',
          ])?.trim() ??
          '';

      if (studentKey.isEmpty) {
        continue;
      }

      final String normalizedStudentKey = studentKey.toLowerCase();
      if (seen.contains(normalizedStudentKey)) {
        continue;
      }
      seen.add(normalizedStudentKey);

      final Map<String, dynamic>? profileData = await _resolveStudentProfile(
        studentKey,
      );
      final Map<String, dynamic> profile = profileData ?? <String, dynamic>{};
      final String? requestName = _readFirstString(requestData, <String>[
        'name',
        'fullName',
        'displayName',
        'studentName',
      ]);
      final String? requestPhotoUrl = _readFirstString(requestData, <String>[
        'photoUrl',
        'photoURL',
        'avatarUrl',
        'profileImageUrl',
        'profileImage',
        'profilePhotoUrl',
        'profilePicture',
        'profile_picture',
        'picture',
        'pictureUrl',
        'imageUrl',
        'image',
        'avatar',
        'avatarImage',
        'studentPhotoUrl',
        'studentPhotoURL',
        'studentPicture',
        'studentAvatar',
      ]);

      students.add(
        _QueueStudentInfo(
          id: studentKey,
          name:
              requestName ??
              _readFirstString(profile, <String>[
                'name',
                'fullName',
                'displayName',
              ]) ??
              studentKey,
          studentId: _readFirstString(profile, <String>[
            'studentId',
            'universityId',
            'id',
          ]),
          photoUrl:
              requestPhotoUrl ??
              _readFirstString(profile, <String>[
                'photoUrl',
                'photoURL',
                'avatarUrl',
                'profileImageUrl',
                'profileImage',
                'profilePhotoUrl',
                'profilePicture',
                'profile_picture',
                'picture',
                'pictureUrl',
                'imageUrl',
                'image',
                'avatarImage',
                'avatar',
                'studentPhotoUrl',
                'studentPhotoURL',
                'studentPicture',
                'studentAvatar',
              ]),
        ),
      );

      if (students.length >= 12) {
        break;
      }
    }

    return students;
  }

  String? _readFirstString(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = data[key];
      if (value == null) {
        continue;
      }

      final String normalized = value.toString().trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _resolveStudentProfile(
    String studentKey,
  ) async {
    final String normalizedKey = studentKey.trim();
    if (normalizedKey.isEmpty) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> docById = await _firestore
        .collection('users')
        .doc(normalizedKey)
        .get();
    if (docById.exists) {
      return docById.data();
    }

    final List<Query<Map<String, dynamic>>> queries =
        <Query<Map<String, dynamic>>>[
          _firestore
              .collection('users')
              .where('studentId', isEqualTo: normalizedKey),
          _firestore
              .collection('users')
              .where('universityId', isEqualTo: normalizedKey),
          _firestore.collection('users').where('uid', isEqualTo: normalizedKey),
          _firestore
              .collection('users')
              .where('email', isEqualTo: normalizedKey),
          _firestore
              .collection('users')
              .where('photoUrl', isEqualTo: normalizedKey),
        ];

    for (final Query<Map<String, dynamic>> query in queries) {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await query
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      }
    }

    final QuerySnapshot<Map<String, dynamic>> allUsersSnapshot =
        await _firestore.collection('users').get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in allUsersSnapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final List<String?> candidates = <String?>[
        _readFirstString(data, <String>[
          'studentId',
          'universityId',
          'id',
          'uid',
          'email',
        ]),
        _readFirstString(data, <String>['name', 'fullName', 'displayName']),
      ];

      final bool matches = candidates.any((String? candidate) {
        if (candidate == null) {
          return false;
        }
        final String normalizedCandidate = candidate.trim().toLowerCase();
        return normalizedCandidate == normalizedKey.toLowerCase() ||
            normalizedCandidate.contains(normalizedKey.toLowerCase()) ||
            normalizedKey.toLowerCase().contains(normalizedCandidate);
      });

      if (matches) {
        return data;
      }
    }

    return null;
  }

  String? _normalizeImageUrl(String? rawUrl) {
    final String? trimmed = rawUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasScheme ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return null;
    }

    return trimmed;
  }

  void _maybeNotifyBusAssigned(TransitProvider transit, AppStrings strings) {
    final String area = transit.studentCurrentArea;
    final String? bus = transit.assignedBusForArea(area);

    if (bus == null) {
      if (_lastBusAssignmentNotificationKey != null &&
          _lastBusAssignmentNotificationKey!.startsWith('$area|')) {
        _lastBusAssignmentNotificationKey = null;
      }
      return;
    }

    final String key = '$area|$bus';
    if (_lastBusAssignmentNotificationKey == key) {
      return;
    }

    _lastBusAssignmentNotificationKey = key;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      messenger.clearMaterialBanners();
      messenger.showMaterialBanner(
        MaterialBanner(
          content: Text(strings.busAssignedToYourArea(area, bus)),
          actions: <Widget>[
            TextButton(
              onPressed: messenger.clearMaterialBanners,
              child: Text(strings.back),
            ),
          ],
        ),
      );

      Future<void>.delayed(const Duration(seconds: 3), () {
        if (!mounted) {
          return;
        }
        messenger.clearMaterialBanners();
      });
    });
  }

  void _maybePromptBusDeparted(TransitProvider transit, AppStrings strings) {
    if (!transit.shouldPromptStudentBoarding ||
        transit.activeRequestArea == null) {
      _lastDepartedPromptKey = null;
      return;
    }

    final String area = transit.activeRequestArea!;
    final String? bus = transit.assignedBusForArea(area);
    if (bus == null) {
      return;
    }

    final String key = '$area|$bus|departed';
    if (_lastDepartedPromptKey == key) {
      return;
    }
    _lastDepartedPromptKey = key;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.busDepartedPrompt)));
    });
  }

  void _maybeNotifyRideCancelled(TransitProvider transit, AppStrings strings) {
    if (transit.hasActiveStudentRequest ||
        transit.activeRequestSummary != null) {
      if (_lastRideCancelledNotificationKey != null) {
        _lastRideCancelledNotificationKey = null;
      }
      return;
    }

    if (_lastSummary == null) {
      return;
    }

    final String key = '${_lastSummary!.area}|cancelled';
    if (_lastRideCancelledNotificationKey == key) {
      return;
    }

    _lastRideCancelledNotificationKey = key;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      messenger.clearMaterialBanners();
      messenger.showMaterialBanner(
        MaterialBanner(
          content: Text(strings.requestCancelledFor(_lastSummary!.area)),
          actions: <Widget>[
            TextButton(
              onPressed: messenger.clearMaterialBanners,
              child: Text(strings.back),
            ),
          ],
        ),
      );

      Future<void>.delayed(const Duration(seconds: 3), () {
        if (!mounted) {
          return;
        }
        messenger.clearMaterialBanners();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final TransitProvider transit = context.watch<TransitProvider>();
    final AppSettingsProvider settings = context.watch<AppSettingsProvider>();
    final AppStrings strings = AppStrings(isArabic: settings.isArabic);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final User? currentUser = _auth.currentUser;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: currentUser == null
          ? null
          : _requestFirestore
              .collection('studentRequests')
              .doc(currentUser.uid)
              .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> requestSnapshot,
      ) {
        final Map<String, dynamic>? persistedRequestData =
            requestSnapshot.data?.data();
        final RequestExecutionSummary? persistedSummary =
            _summaryFromPersistedRequest(transit, persistedRequestData);
        final RequestExecutionSummary? activeSummary =
            persistedSummary ?? transit.activeRequestSummary;
        final bool hasValidActiveRequest = activeSummary != null;
        final bool canConfirmRequest =
            !hasValidActiveRequest && transit.pickupAreas.isNotEmpty;
        final RequestExecutionSummary? summaryForView = hasValidActiveRequest
            ? RequestExecutionSummary(
                area: activeSummary.area,
                studentsWaiting: transit.waitingStudentsForArea(activeSummary.area),
                busNumber:
                    transit.assignedBusForArea(activeSummary.area) ??
                    activeSummary.busNumber,
              )
            : null;

        _maybeNotifyBusAssigned(transit, strings);
        _maybePromptBusDeparted(transit, strings);
        _maybeNotifyRideCancelled(transit, strings);

        return Scaffold(
          body: AppShellBackground(
            child: transit.loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        HeaderRow(title: strings.appName),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton.filledTonal(
                            onPressed: settings.toggleTheme,
                            icon: Icon(
                              settings.isDarkMode
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.glass.withValues(alpha: 0.32)
                                : Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                strings.onDemandTransit,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: isDark
                                          ? AppColors.accentLight
                                          : AppColors.accent,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                strings.requestRide,
                                style: Theme.of(context).textTheme.headlineLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                strings.requestSubtitle,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const SizedBox(height: 24),
                        Text(
                          strings.pickupArea,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                color:
                                    (isDark
                                            ? AppColors.textPrimary
                                            : const Color(0xFF111827))
                                        .withValues(alpha: 0.72),
                              ),
<<<<<<< HEAD
=======
                            )
                            .toList(),
                        onChanged: (String? value) {
                          if (value != null) {
                            transit.selectPickupArea(value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    const PreBookingPanel(),
                    const SizedBox(height: 22),
                    if (!hasValidActiveRequest)
                      CustomButton(
                        label: strings.confirmRequest,
                        icon: Icons.arrow_forward,
                        onPressed: () {
                          if (!canConfirmRequest) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(strings.requestAreaRequired),
                              ),
                            );
                            return;
                          }

                          final RequestExecutionSummary summary = transit
                              .executeImmediateRequest();
                          setState(() {
                            _lastSummary = summary;
                          });

                          final List<String> buses = transit.busesForArea(
                            summary.area,
                          );
                          final String busText =
                              summary.busNumber == null ||
                                  summary.busNumber!.trim().isEmpty
                              ? strings.noBusAssigned
                              : 'BUS #${summary.busNumber}';
                          final String additionalBusesText = buses.length > 1
                              ? ' | ${strings.additionalBusesAvailableCount(buses.length - 1)}'
                              : '';

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${strings.selectedArea}: ${summary.area} | '
                                '${strings.currentlyWaiting}: ${summary.studentsWaiting} ${strings.students} | '
                                '${strings.assignedBus}: $busText$additionalBusesText',
                              ),
                            ),
                          );
                        },
                      )
                    else
                      CustomButton(
                        label: strings.cancelRequest,
                        icon: Icons.cancel_outlined,
                        onPressed: () {
                          final RequestExecutionSummary? cancelled = transit
                              .cancelRequestForArea(activeSummary.area);

                          if (cancelled == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(strings.noActiveRequest)),
                            );
                            return;
                          }

                          setState(() {
                            _lastSummary = null;
                            _lastBusAssignmentNotificationKey = null;
                            _lastDepartedPromptKey = null;
                          });
                        },
                      ),
                    if (summaryForView != null) ...<Widget>[
                      const SizedBox(height: 20),
                      InfoCard(
                        title: strings.selectedArea,
                        value: summaryForView.area,
                      ),
                      const SizedBox(height: 12),
                      _buildQueueSnapshotCard(
                        context: context,
                        strings: strings,
                        transit: transit,
                        summary: summaryForView,
                        isDark: isDark,
                      ),
                      if (transit.busesForArea(summaryForView.area).length >
                          1) ...<Widget>[
                        const SizedBox(height: 12),
                        InfoCard(
                          title: strings.assignedBuses,
                          value: transit
                              .busesForArea(summaryForView.area)
                              .map((String bus) => 'BUS #$bus')
                              .join(' • '),
                          indicatorColor: const Color(0xFF4B5B78),
>>>>>>> b0f742e9c75f062b475a704e778e766672c798d1
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.glass.withValues(alpha: 0.34)
                                : const Color(0xFFEFF2F8),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                          child: DropdownButtonFormField<String>(
                            initialValue: transit.selectedPickupArea,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            dropdownColor:
                                isDark ? AppColors.surface : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            style: Theme.of(context).textTheme.headlineMedium,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                            items: transit.pickupAreas
                                .map(
                                  (String area) => DropdownMenuItem<String>(
                                    value: area,
                                    child: Text(
                                      area,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: isDark
                                                ? AppColors.textPrimary
                                                : AppColors.lightTextPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (String? value) {
                              if (value != null) {
                                transit.selectPickupArea(value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 22),
                        if (!hasValidActiveRequest)
                          CustomButton(
                            label: strings.confirmRequest,
                            icon: Icons.arrow_forward,
                            onPressed: () async {
                              final ScaffoldMessengerState messenger =
                                  ScaffoldMessenger.of(context);
                              if (!canConfirmRequest) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(strings.requestAreaRequired),
                                  ),
                                );
                                return;
                              }

                              final RequestExecutionSummary summary = await transit
                                  .executeImmediateRequest();
                              if (!mounted) {
                                return;
                              }
                              setState(() {
                                _lastSummary = summary;
                              });

                              final List<String> buses = transit.busesForArea(
                                summary.area,
                              );
                              final String busText =
                                  summary.busNumber == null ||
                                      summary.busNumber!.trim().isEmpty
                                  ? strings.noBusAssigned
                                  : 'BUS #${summary.busNumber}';
                              final String additionalBusesText = buses.length > 1
                                  ? ' | ${strings.additionalBusesAvailableCount(buses.length - 1)}'
                                  : '';

                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${strings.selectedArea}: ${summary.area} | '
                                    '${strings.currentlyWaiting}: ${summary.studentsWaiting} ${strings.students} | '
                                    '${strings.assignedBus}: $busText$additionalBusesText',
                                  ),
                                ),
                              );
                            },
                          )
                        else
                          CustomButton(
                            label: strings.cancelRequest,
                            icon: Icons.cancel_outlined,
                            onPressed: () {
                              final RequestExecutionSummary? cancelled = transit
                                  .cancelRequestForArea(activeSummary.area);

                              if (cancelled == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(strings.noActiveRequest)),
                                );
                                return;
                              }

                              setState(() {
                                _lastSummary = null;
                                _lastBusAssignmentNotificationKey = null;
                                _lastDepartedPromptKey = null;
                              });
                            },
                          ),
                        if (summaryForView != null) ...<Widget>[
                          const SizedBox(height: 20),
                          InfoCard(
                            title: strings.selectedArea,
                            value: summaryForView.area,
                          ),
                          const SizedBox(height: 12),
                          _buildQueueSnapshotCard(
                            context: context,
                            strings: strings,
                            transit: transit,
                            summary: summaryForView,
                            isDark: isDark,
                          ),
                          if (transit.busesForArea(summaryForView.area).length >
                              1) ...<Widget>[
                            const SizedBox(height: 12),
                            InfoCard(
                              title: strings.assignedBuses,
                              value: transit
                                  .busesForArea(summaryForView.area)
                                  .map((String bus) => 'BUS #$bus')
                                  .join(' • '),
                              indicatorColor: const Color(0xFF4B5B78),
                            ),
                          ],
                          if (transit.shouldPromptStudentBoarding) ...<Widget>[
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(
                                      Icons.check_circle_outline_rounded,
                                    ),
                                    label: Text(strings.iBoarded),
                                    onPressed: () {
                                      final bool ok = transit
                                          .markCurrentStudentBoarded();
                                      if (!ok) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              strings.boardingNotAvailable,
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      setState(() {
                                        _lastSummary = null;
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(strings.boardedConfirmed),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.schedule_rounded),
                                    label: Text(strings.iDidNotBoard),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            strings.keptInWaitingList,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _QueueStudentInfo {
  const _QueueStudentInfo({
    required this.id,
    required this.name,
    this.studentId,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String? studentId;
  final String? photoUrl;
}
