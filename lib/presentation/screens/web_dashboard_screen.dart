import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/zone.dart';
import '../localization/app_strings.dart';
import '../providers/app_settings_provider.dart';
import '../providers/transit_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell_background.dart';

class WebDashboardScreen extends StatelessWidget {
  const WebDashboardScreen({super.key});

  Future<void> _refresh(BuildContext context) async {
    await context.read<TransitProvider>().load(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final TransitProvider transit = context.watch<TransitProvider>();
    final AppSettingsProvider settings = context.watch<AppSettingsProvider>();
    final AppStrings strings = AppStrings(isArabic: settings.isArabic);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final int activeZones = transit.zones
        .where((Zone zone) => zone.studentsWaiting > 0)
        .length;
    final int assignedZones = transit.zones
        .where((Zone zone) => (zone.assignedBus ?? '').trim().isNotEmpty)
        .length;
    final int criticalZones = transit.zones
        .where((Zone zone) => zone.severity == ZoneSeverity.critical)
        .length;

    return Scaffold(
      body: AppShellBackground(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: transit.loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => _refresh(context),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool compact = constraints.maxWidth < 980;
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: <Widget>[
                        _HeaderBand(
                          title: settings.isArabic
                              ? 'لوحة متابعة النقل'
                              : 'Transit Operations Dashboard',
                          subtitle: settings.isArabic
                              ? 'مراقبة لحظية لانتظار الطلاب وحركة الحافلات'
                              : 'Live monitoring for student queues and fleet movement',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: <Widget>[
                            _MetricTile(
                              title: strings.currentlyWaiting,
                              value: transit.waitingStudents.toString(),
                              hint: strings.students,
                              icon: Icons.groups_rounded,
                              tint: AppColors.accentLight,
                              width: compact
                                  ? constraints.maxWidth
                                  : (constraints.maxWidth - 12) / 2,
                            ),
                            _MetricTile(
                              title: strings.activeZones,
                              value: activeZones.toString(),
                              hint: strings.systemLive,
                              icon: Icons.map_rounded,
                              tint: AppColors.stable,
                              width: compact
                                  ? constraints.maxWidth
                                  : (constraints.maxWidth - 12) / 2,
                            ),
                            _MetricTile(
                              title: strings.fleetStatus,
                              value: assignedZones.toString(),
                              hint: settings.isArabic
                                  ? 'مناطق بها حافلة مخصصة'
                                  : 'Zones with assigned buses',
                              icon: Icons.directions_bus_filled_rounded,
                              tint: AppColors.moderate,
                              width: compact
                                  ? constraints.maxWidth
                                  : (constraints.maxWidth - 24) / 3,
                            ),
                            _MetricTile(
                              title: settings.isArabic
                                  ? 'مناطق حرجة'
                                  : 'Critical Zones',
                              value: criticalZones.toString(),
                              hint: settings.isArabic
                                  ? 'تحتاج تدخل فوري'
                                  : 'Need immediate action',
                              icon: Icons.warning_amber_rounded,
                              tint: AppColors.critical,
                              width: compact
                                  ? constraints.maxWidth
                                  : (constraints.maxWidth - 24) / 3,
                            ),
                            _MetricTile(
                              title: strings.campusConnectivity,
                              value: transit.campusConnectivity,
                              hint: strings.lastUpdated,
                              icon: Icons.network_check_rounded,
                              tint: AppColors.accent,
                              width: compact
                                  ? constraints.maxWidth
                                  : (constraints.maxWidth - 24) / 3,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (compact) ...<Widget>[
                          _OperationsCard(
                            strings: strings,
                            settings: settings,
                            transit: transit,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 12),
                          _ZonesCard(
                            strings: strings,
                            settings: settings,
                            transit: transit,
                          ),
                        ] else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                flex: 7,
                                child: _ZonesCard(
                                  strings: strings,
                                  settings: settings,
                                  transit: transit,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 4,
                                child: _OperationsCard(
                                  strings: strings,
                                  settings: settings,
                                  transit: transit,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _HeaderBand extends StatelessWidget {
  const _HeaderBand({
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  final String title;
  final String subtitle;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFF102042), Color(0xFF182D5B)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFFEAF3FF), Color(0xFFD9E8FF)],
              ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.78),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.title,
    required this.value,
    required this.hint,
    required this.icon,
    required this.tint,
    required this.width,
  });

  final String title;
  final String value;
  final String hint;
  final IconData icon;
  final Color tint;
  final double width;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: width,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
        tween: Tween<double>(begin: 0.95, end: 1),
        builder: (BuildContext context, double valueAnim, Widget? child) {
          return Transform.scale(scale: valueAnim, child: child);
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.glass.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(hint, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZonesCard extends StatelessWidget {
  const _ZonesCard({
    required this.strings,
    required this.settings,
    required this.transit,
  });

  final AppStrings strings;
  final AppSettingsProvider settings;
  final TransitProvider transit;

  Color _severityColor(ZoneSeverity severity) {
    switch (severity) {
      case ZoneSeverity.critical:
        return AppColors.critical;
      case ZoneSeverity.moderate:
        return AppColors.moderate;
      case ZoneSeverity.stable:
        return AppColors.stable;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surface.withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.96),
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
            strings.campusLoadingZones,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...transit.zones.map(
            (Zone zone) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _severityColor(zone.severity),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      zone.name,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  Text(
                    settings.isArabic
                        ? '${zone.studentsWaiting} طالب'
                        : '${zone.studentsWaiting} students',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    (zone.assignedBus ?? '').trim().isEmpty
                        ? (settings.isArabic ? 'بدون باص' : 'No bus')
                        : 'BUS #${zone.assignedBus}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: (zone.assignedBus ?? '').trim().isEmpty
                          ? (isDark
                                ? AppColors.textMuted
                                : AppColors.lightTextSecondary)
                          : AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationsCard extends StatelessWidget {
  const _OperationsCard({
    required this.strings,
    required this.settings,
    required this.transit,
    required this.isDark,
  });

  final AppStrings strings;
  final AppSettingsProvider settings;
  final TransitProvider transit;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final RequestExecutionSummary? active = transit.activeRequestSummary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surface.withValues(alpha: 0.52)
            : Colors.white.withValues(alpha: 0.96),
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
            settings.isArabic ? 'ملخص العمليات' : 'Operations Summary',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _OperationRow(
            label: strings.activeStatus,
            value: transit.systemStatus,
          ),
          _OperationRow(label: strings.fleetStatus, value: transit.fleetStatus),
          _OperationRow(
            label: strings.selectedArea,
            value: transit.selectedPickupArea,
          ),
          const Divider(height: 22),
          Text(
            strings.requestSummaryTitle,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Text(
            active == null
                ? (settings.isArabic
                      ? 'لا يوجد طلب نشط الآن'
                      : 'No active request right now')
                : '${active.area} • ${active.studentsWaiting} ${settings.isArabic ? 'منتظر' : 'waiting'}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 6),
          Text(
            active?.busNumber == null
                ? strings.noBusAssigned
                : 'BUS #${active!.busNumber}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _OperationRow extends StatelessWidget {
  const _OperationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
