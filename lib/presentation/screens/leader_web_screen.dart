
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_strings.dart';
import '../../domain/entities/zone.dart';
import '../providers/app_settings_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/transit_provider.dart';
import '../providers/unified_auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell_background.dart';
import 'role_selection_screen.dart';

class LeaderWebScreen extends StatefulWidget {
  const LeaderWebScreen({super.key});

  @override
  State<LeaderWebScreen> createState() => _LeaderWebScreenState();
}

class _LeaderWebScreenState extends State<LeaderWebScreen> {
  final Map<String, TextEditingController> _busInputControllers =
      <String, TextEditingController>{};

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

  TextEditingController _busControllerForZone(String zoneId) {
    return _busInputControllers.putIfAbsent(
      zoneId,
      () => TextEditingController(),
    );
  }

  void _cleanupBusControllers(Iterable<String> activeZoneIds) {
    final Set<String> activeIds = activeZoneIds.toSet();
    final List<String> staleIds = _busInputControllers.keys
        .where((String id) => !activeIds.contains(id))
        .toList();

    for (final String id in staleIds) {
      _busInputControllers.remove(id)?.dispose();
    }
  }

  Future<void> _logoutLeader() async {
    final AuthProvider auth = context.read<AuthProvider>();
    final AppSettingsProvider settings = context.read<AppSettingsProvider>();
    final AppStrings strings = AppStrings(isArabic: settings.isArabic);

    await auth.logoutLeader();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const RoleSelectionScreen()),
      (Route<dynamic> route) => false,
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(strings.leaderSignedOut)));
  }

  Future<void> _refreshTransit() async {
    await context.read<TransitProvider>().load(force: true);
    if (!mounted) {
      return;
    }

    final bool isArabic = context.read<AppSettingsProvider>().isArabic;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isArabic ? 'تم تحديث لوحة القائد.' : 'Leader dashboard refreshed.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _confirmClearAllRequests(AppStrings strings) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(strings.clearAllRequestsConfirmTitle),
          content: Text(strings.clearAllRequestsConfirmMessage),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.back),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(strings.confirm),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<int?> _askBoardedCount(AppStrings strings) async {
    final TextEditingController countController = TextEditingController();
    final int? result = await showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(strings.enterBoardedCount),
          content: TextField(
            controller: countController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(hintText: strings.boardedCountHint),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.back),
            ),
            FilledButton(
              onPressed: () {
                final int? parsed = int.tryParse(countController.text.trim());
                if (parsed == null || parsed <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(strings.boardedCountRequired)),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(parsed);
              },
              child: Text(strings.confirm),
            ),
          ],
        );
      },
    );
    countController.dispose();
    return result;
  }

  Future<bool> _confirmSoftDeleteZone(
    AppStrings strings,
    String zoneName,
  ) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(strings.deleteZoneConfirmTitle(zoneName)),
          content: Text(strings.deleteZoneConfirmMessage(zoneName)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.back),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(strings.confirm),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<bool> _confirmPermanentDeleteZone(
    AppStrings strings,
    String zoneName,
  ) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(strings.permanentDeleteZoneConfirmTitle(zoneName)),
          content: Text(strings.permanentDeleteZoneConfirmMessage(zoneName)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.back),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(strings.deletePermanently),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  @override
  void dispose() {
    for (final TextEditingController controller
        in _busInputControllers.values) {
      controller.dispose();
    }
    _busInputControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TransitProvider transit = context.watch<TransitProvider>();
    final AppSettingsProvider settings = context.watch<AppSettingsProvider>();
    final UnifiedAuthProvider unifiedAuth = context
        .watch<UnifiedAuthProvider>();
    final AppStrings strings = AppStrings(isArabic: settings.isArabic);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool wideLayout = MediaQuery.sizeOf(context).width >= 1100;

    final String displayName =
        unifiedAuth.currentName?.trim().isNotEmpty == true
        ? unifiedAuth.currentName!.trim()
        : strings.leaderLogin;
    final String? profilePhotoUrl = _normalizeImageUrl(
      unifiedAuth.currentPhotoUrl,
    );
    final Uint8List? profilePhotoBytes = unifiedAuth.currentPhotoBytes;
    final ImageProvider<Object>? avatarImage = profilePhotoBytes != null
        ? MemoryImage(profilePhotoBytes)
        : (profilePhotoUrl != null ? NetworkImage(profilePhotoUrl) : null);

    final int activeZones = transit.zones
        .where((zone) => zone.studentsWaiting > 0)
        .length;
    final int assignedBusZones = transit.zones
        .where((zone) => (zone.assignedBus ?? '').trim().isNotEmpty)
        .length;

    return Scaffold(
      body: AppShellBackground(
        child: transit.loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refreshTransit,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _buildTopBar(
                          context: context,
                          strings: strings,
                          settings: settings,
                          avatarImage: avatarImage,
                          displayName: displayName,
                          profilePhotoBytes: profilePhotoBytes,
                        ),
                        const SizedBox(height: 22),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: LinearGradient(
                              colors: isDark
                                  ? <Color>[
                                      const Color(0xFF101D3A),
                                      const Color(0xFF15284D),
                                    ]
                                  : <Color>[
                                      const Color(0xFFECF5FF),
                                      const Color(0xFFDDEBFF),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.white.withValues(alpha: 0.68),
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.24 : 0.08,
                                ),
                                blurRadius: 30,
                                spreadRadius: -14,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                strings.leaderPanelTitle,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: isDark
                                          ? AppColors.accentLight
                                          : AppColors.accent,
                                      letterSpacing: 0.4,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                strings.leaderPanelSubtitle,
                                style: Theme.of(context).textTheme.displayLarge,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                strings.fleetCommandSubtitle,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: isDark
                                          ? AppColors.textSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        LayoutBuilder(
                          builder:
                              (
                                BuildContext context,
                                BoxConstraints constraints,
                              ) {
                                final bool compactStats =
                                    constraints.maxWidth < 760;
                                final List<Widget> stats = <Widget>[
                                  _StatTile(
                                    title: strings.currentlyWaiting,
                                    value: transit.waitingStudents.toString(),
                                    subtitle: strings.students,
                                    icon: Icons.groups_rounded,
                                    accentColor: AppColors.accentLight,
                                  ),
                                  _StatTile(
                                    title: strings.activeZones,
                                    value: activeZones.toString(),
                                    subtitle: strings.localizeSystemStatus(
                                      transit.systemStatus,
                                    ),
                                    icon: Icons.published_with_changes_rounded,
                                    accentColor: AppColors.moderate,
                                  ),
                                  _StatTile(
                                    title: strings.fleetStatus,
                                    value: assignedBusZones.toString(),
                                    subtitle: strings
                                        .localizeCampusConnectivity(
                                          transit.campusConnectivity,
                                        ),
                                    icon: Icons.directions_bus_rounded,
                                    accentColor: AppColors.stable,
                                  ),
                                ];

                                return Wrap(
                                  spacing: 14,
                                  runSpacing: 14,
                                  children: stats
                                      .map(
                                        (Widget stat) => SizedBox(
                                          width: compactStats
                                              ? constraints.maxWidth
                                              : (constraints.maxWidth - 28) / 3,
                                          child: stat,
                                        ),
                                      )
                                      .toList(),
                                );
                              },
                        ),
                        const SizedBox(height: 18),
                        if (wideLayout)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                flex: 7,
                                child: _buildZoneBoard(
                                  context,
                                  transit,
                                  strings,
                                  isDark,
                                ),
                              ),
                              const SizedBox(width: 18),
                              SizedBox(
                                width: 360,
                                child: _buildSidePanel(
                                  context: context,
                                  transit: transit,
                                  strings: strings,
                                  isDark: isDark,
                                  activeZones: activeZones,
                                  assignedBusZones: assignedBusZones,
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: <Widget>[
                              _buildSidePanel(
                                context: context,
                                transit: transit,
                                strings: strings,
                                isDark: isDark,
                                activeZones: activeZones,
                                assignedBusZones: assignedBusZones,
                              ),
                              const SizedBox(height: 18),
                              _buildZoneBoard(
                                context,
                                transit,
                                strings,
                                isDark,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTopBar({
    required BuildContext context,
    required AppStrings strings,
    required AppSettingsProvider settings,
    required ImageProvider<Object>? avatarImage,
    required String displayName,
    required Uint8List? profilePhotoBytes,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                strings.appName,
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(letterSpacing: 1.2),
              ),
              const SizedBox(height: 4),
              Text(
                strings.portalTitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            IconButton.filledTonal(
              onPressed: settings.toggleTheme,
              icon: Icon(
                settings.isDarkMode
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _refreshTransit,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(strings.back),
            ),
            TextButton.icon(
              onPressed: _logoutLeader,
              icon: const Icon(Icons.logout_rounded),
              label: Text(strings.leaderSignOut),
            ),
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              backgroundImage: avatarImage,
              foregroundImage: avatarImage,
              child: (profilePhotoBytes == null && avatarImage == null)
                  ? Text(
                      displayName.isNotEmpty
                          ? displayName.characters.first.toUpperCase()
                          : 'L',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSidePanel({
    required BuildContext context,
    required TransitProvider transit,
    required AppStrings strings,
    required bool isDark,
    required int activeZones,
    required int assignedBusZones,
  }) {
    return Column(
      children: <Widget>[
        _PanelCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                isDark ? 'Live Actions' : 'Live Actions',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _refreshTransit,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(strings.requestSummaryTitle),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: transit.waitingStudents <= 0
                    ? null
                    : () async {
                        final bool confirmed = await _confirmClearAllRequests(
                          strings,
                        );
                        if (!confirmed || !context.mounted) {
                          return;
                        }
                        final int removed = transit
                            .clearWaitingStudentsForAllZones();
                        if (removed > 0 && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                strings.allRequestsCleared(removed),
                              ),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.delete_sweep_outlined),
                label: Text(strings.clearAllRequests),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _logoutLeader,
                icon: const Icon(Icons.logout_rounded),
                label: Text(strings.leaderSignOut),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _PanelCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                strings.systemLive,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              _StatusRow(
                label: strings.activeStatus,
                value: strings.localizeSystemStatus(transit.systemStatus),
                icon: Icons.verified_rounded,
                color: AppColors.stable,
              ),
              const SizedBox(height: 10),
              _StatusRow(
                label: strings.campusConnectivity,
                value: strings.localizeCampusConnectivity(
                  transit.campusConnectivity,
                ),
                icon: Icons.wifi_rounded,
                color: AppColors.accentLight,
              ),
              const SizedBox(height: 10),
              _StatusRow(
                label: strings.currentlyWaiting,
                value: transit.waitingStudents.toString(),
                icon: Icons.groups_rounded,
                color: AppColors.moderate,
              ),
              const SizedBox(height: 10),
              _StatusRow(
                label: strings.fleetStatus,
                value: assignedBusZones.toString(),
                icon: Icons.directions_bus_rounded,
                color: AppColors.accentLight,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _PanelCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                strings.leaderPanelTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                strings.leaderPanelSubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${strings.activeZones}: $activeZones',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _PanelCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      strings.deletedZones,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.critical.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      transit.deletedZones.length.toString(),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.critical,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (transit.deletedZones.isEmpty)
                Text(
                  strings.noDeletedZones,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              else
                ...transit.deletedZones.map(
                  (Zone zone) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.glass.withValues(alpha: 0.18)
                          : const Color(0xFFF5F7FB),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          strings.localizeZoneName(zone.name),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            OutlinedButton.icon(
                              onPressed: () {
                                final bool restored = transit
                                    .restoreDeletedZone(zone.id);
                                if (!restored) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      strings.zoneRestored(
                                        strings.localizeZoneName(zone.name),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.restore_rounded, size: 16),
                              label: Text(strings.restoreZone),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () async {
                                final bool confirmed =
                                    await _confirmPermanentDeleteZone(
                                      strings,
                                      strings.localizeZoneName(zone.name),
                                    );
                                if (!confirmed || !context.mounted) {
                                  return;
                                }
                                final bool deleted = transit
                                    .deleteZonePermanently(zone.id);
                                if (!deleted || !context.mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      strings.zonePermanentlyDeleted(
                                        strings.localizeZoneName(zone.name),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.delete_forever_rounded,
                                size: 16,
                              ),
                              label: Text(strings.deletePermanently),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildZoneBoard(
    BuildContext context,
    TransitProvider transit,
    AppStrings strings,
    bool isDark,
  ) {
    _cleanupBusControllers(transit.zones.map((Zone zone) => zone.id));

    final List<Widget> zoneCards = transit.zones
        .map(
          (Zone zone) =>
              _buildZoneCard(context, transit, zone, strings, isDark),
        )
        .toList();

    return _PanelCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  strings.campusLoadingZones,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentLight.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${zoneCards.length} zones',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.accentLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...zoneCards,
        ],
      ),
    );
  }

  Widget _buildZoneCard(
    BuildContext context,
    TransitProvider transit,
    Zone zone,
    AppStrings strings,
    bool isDark,
  ) {
    final Color severityColor = switch (zone.severity) {
      ZoneSeverity.critical => AppColors.critical,
      ZoneSeverity.moderate => AppColors.moderate,
      ZoneSeverity.stable => AppColors.stable,
    };

    final String severityText = switch (zone.severity) {
      ZoneSeverity.critical => strings.critical,
      ZoneSeverity.moderate => strings.moderate,
      ZoneSeverity.stable => strings.stable,
    };
    final int boardedCount = transit.boardedCountForZone(zone.id);
    final List<String> zoneBuses = transit.assignedBusesForZone(zone.id);
    final TextEditingController busController = _busControllerForZone(zone.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surface.withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(22),
        border: Border(left: BorderSide(width: 4, color: severityColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      strings.localizeZoneName(zone.name),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${zone.studentsWaiting.toString().padLeft(2, '0')} ${strings.studentsWaitingLabel}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  severityText,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: severityColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _ZoneBadge(
                label: zone.assignedBus == null
                    ? strings.noBusAssigned
                    : 'BUS #${zone.assignedBus}',
                icon: Icons.directions_bus_rounded,
                color: zone.assignedBus == null
                    ? AppColors.critical
                    : AppColors.stable,
              ),
              const SizedBox(width: 10),
              if (zoneBuses.length > 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.moderate.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.moderate.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '+${zoneBuses.length - 1}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.moderate,
                    ),
                  ),
                ),
              if (zoneBuses.length > 1) const SizedBox(width: 8),
              if (zone.assignedBus != null && transit.isBusDeparted(zone.id))
                _ZoneBadge(
                  label: strings.departed,
                  icon: Icons.check_circle_rounded,
                  color: AppColors.stable,
                ),
              if (zone.assignedBus != null && transit.isBusDeparted(zone.id))
                const SizedBox(width: 10),
              if (boardedCount > 0)
                _ZoneBadge(
                  label: '${strings.boardedCountLabel}: $boardedCount',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.accentLight,
                ),
            ],
          ),
          if (zoneBuses.length > 1) ...<Widget>[
            const SizedBox(height: 12),
            Column(
              children: zoneBuses.map((String bus) {
                final bool isPrimary = bus == zoneBuses.first;
                final bool departed = transit.isSpecificBusDeparted(
                  zone.id,
                  bus,
                );
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.glass.withValues(alpha: 0.28)
                        : const Color(0xFFEFF2F8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          isPrimary
                              ? 'BUS #$bus (${strings.assign})'
                              : 'BUS #$bus',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      if (departed)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: Text(
                            strings.departed,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppColors.stable),
                          ),
                        ),
                      if (!departed)
                        IconButton(
                          tooltip: strings.markDeparted,
                          onPressed: () {
                            transit.markSpecificBusDeparted(zone.id, bus);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(strings.busMarkedDeparted(bus)),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                            color: AppColors.stable,
                          ),
                        ),
                      IconButton(
                        tooltip: strings.remove,
                        onPressed: () {
                          transit.removeSpecificBus(zone.id, bus);
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.accentLight,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: busController,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: strings.enterBus,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (zone.assignedBus == null)
                SizedBox(
                  width: 118,
                  child: FilledButton(
                    onPressed: () {
                      final String bus = busController.text.trim();
                      final String normalizedBus = bus
                          .toUpperCase()
                          .replaceAll('BUS #', '')
                          .trim();
                      if (bus.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(strings.busRequired)),
                        );
                        return;
                      }
                      if (normalizedBus.startsWith('0')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(strings.busCannotStartWithZero),
                          ),
                        );
                        return;
                      }
                      final bool ok = transit.assignBus(zone.id, bus);
                      if (!ok) {
                        return;
                      }
                      busController.clear();
                    },
                    child: Text(strings.assign),
                  ),
                )
              else
                FilledButton.tonalIcon(
                  onPressed: () {
                    final String bus = busController.text.trim();
                    final String normalizedBus = bus
                        .toUpperCase()
                        .replaceAll('BUS #', '')
                        .trim();
                    if (bus.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(strings.busRequired)),
                      );
                      return;
                    }
                    if (normalizedBus.startsWith('0')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(strings.busCannotStartWithZero)),
                      );
                      return;
                    }
                    final bool ok = transit.addBusToZone(zone.id, bus);
                    if (!ok) {
                      return;
                    }
                    busController.clear();
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: Text(strings.addBus),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              spacing: 2,
              runSpacing: 2,
              children: <Widget>[
                if (zone.assignedBus != null && !transit.isBusDeparted(zone.id))
                  TextButton.icon(
                    onPressed: () {
                      transit.markBusDeparted(zone.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            strings.busMarkedDeparted(zone.assignedBus!),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 16,
                    ),
                    label: Text(
                      strings.markDeparted,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.stable,
                      ),
                    ),
                  ),
                if (zone.assignedBus != null)
                  TextButton.icon(
                    onPressed: () {
                      transit.removeBus(zone.id);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: Text(
                      strings.remove,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.accentLight,
                      ),
                    ),
                  ),
                TextButton.icon(
                  onPressed: zone.studentsWaiting <= 0
                      ? null
                      : () async {
                          final int? requested = await _askBoardedCount(
                            strings,
                          );
                          if (requested == null || !context.mounted) {
                            return;
                          }
                          final int available = transit.waitingCountForZone(
                            zone.id,
                          );
                          if (available <= 0) {
                            return;
                          }

                          int toApply = requested;
                          if (requested > available) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  strings.boardedCountExceedsAvailable(
                                    available,
                                  ),
                                ),
                              ),
                            );
                            toApply = available;
                          }

                          final int applied = transit.leaderMarkStudentsBoarded(
                            zone.id,
                            toApply,
                          );
                          if (applied > 0 && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  strings.studentsMarkedBoarded(
                                    strings.localizeZoneName(zone.name),
                                    applied,
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                  icon: const Icon(
                    Icons.remove_circle_outline_rounded,
                    size: 16,
                  ),
                  label: Text(
                    strings.markStudentBoarded,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.moderate,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: zone.studentsWaiting <= 0
                      ? null
                      : () {
                          final int removed = transit
                              .clearWaitingStudentsForZone(zone.id);
                          if (removed > 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  strings.requestsCleared(
                                    strings.localizeZoneName(zone.name),
                                    removed,
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.group_remove_outlined, size: 16),
                  label: Text(
                    strings.clearRequests,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.critical,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final String localizedName = strings.localizeZoneName(
                      zone.name,
                    );
                    final bool confirmed = await _confirmSoftDeleteZone(
                      strings,
                      localizedName,
                    );
                    if (!confirmed || !context.mounted) {
                      return;
                    }
                    final bool deleted = transit.softDeleteZone(zone.id);
                    if (!deleted || !context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(strings.zoneDeleted(localizedName)),
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: Text(
                    strings.deleteZone,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.accentLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child, required this.isDark});

  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surface.withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: child,
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surface.withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          const SizedBox(width: 10),
          Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ZoneBadge extends StatelessWidget {
  const _ZoneBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
