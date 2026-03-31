import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/zone.dart';
import '../localization/app_strings.dart';
import '../providers/app_settings_provider.dart';
import '../providers/transit_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell_background.dart';
import '../widgets/header_row.dart';

class FleetManagementScreen extends StatefulWidget {
  const FleetManagementScreen({super.key});

  @override
  State<FleetManagementScreen> createState() => _FleetManagementScreenState();
}

class _FleetManagementScreenState extends State<FleetManagementScreen> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};

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
            decoration: InputDecoration(
              hintText: strings.boardedCountHint,
            ),
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

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TransitProvider transit = context.watch<TransitProvider>();
    final AppSettingsProvider settings = context.watch<AppSettingsProvider>();
    final AppStrings strings = AppStrings(isArabic: settings.isArabic);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AppShellBackground(
        child: transit.loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    HeaderRow(title: strings.academicWayfinder),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surface.withValues(alpha: 0.72)
                            : Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            strings.fleetCommandTitle,
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            strings.fleetCommandSubtitle,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      strings.campusLoadingZones,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.accentLight,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ...transit.zones
                        .map((Zone zone) => _zoneCard(context, transit, zone, strings)),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _zoneCard(
    BuildContext context,
    TransitProvider transit,
    Zone zone,
    AppStrings strings,
  ) {
    final TextEditingController controller =
        _controllers.putIfAbsent(zone.id, TextEditingController.new);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

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
    final bool departed = transit.isBusDeparted(zone.id);
    final int boardedCount = transit.boardedCountForZone(zone.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surface.withValues(alpha: 0.68)
            : Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(24),
        border: Border(
          left: BorderSide(width: 4, color: severityColor),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.1),
            blurRadius: 20,
            spreadRadius: -10,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
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
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 10),
                    RichText(
                      text: TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: zone.studentsWaiting.toString().padLeft(2, '0'),
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(fontSize: 40),
                          ),
                          TextSpan(
                            text: '  ${strings.studentsWaitingLabel}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: severityColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  severityText,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: severityColor,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (zone.assignedBus != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceSoft : const Color(0xFFEFF2F8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.directions_bus, color: AppColors.accentLight),
                      const SizedBox(width: 12),
                      Text(
                        zone.assignedBus!,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(width: 8),
                      if (departed)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.stable.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.stable.withValues(alpha: 0.45)),
                          ),
                          child: Text(
                            strings.departed,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.stable,
                                ),
                          ),
                        ),
                      if (boardedCount > 0) ...<Widget>[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentLight.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.accentLight.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            '${strings.boardedCountLabel}: $boardedCount',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.accentLight,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Wrap(
                      spacing: 2,
                      runSpacing: 2,
                      children: <Widget>[
                        if (!departed)
                          TextButton.icon(
                            onPressed: () {
                              transit.markBusDeparted(zone.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(strings.busMarkedDeparted(zone.assignedBus!))),
                              );
                            },
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                            label: Text(
                              strings.markDeparted,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: AppColors.stable,
                                  ),
                            ),
                          ),
                        TextButton.icon(
                          onPressed: zone.studentsWaiting <= 0
                              ? null
                              : () async {
                                  final int? requested = await _askBoardedCount(strings);
                                  if (requested == null) {
                                    return;
                                  }
                                  if (!context.mounted) {
                                    return;
                                  }
                                  final int available = transit.waitingCountForZone(zone.id);
                                  if (available <= 0) {
                                    return;
                                  }

                                  int toApply = requested;
                                  if (requested > available) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          strings.boardedCountExceedsAvailable(available),
                                        ),
                                      ),
                                    );
                                    toApply = available;
                                  }
                                  final int applied = transit.leaderMarkStudentsBoarded(
                                    zone.id,
                                    toApply,
                                  );
                                  if (applied > 0) {
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
                          icon: const Icon(Icons.remove_circle_outline_rounded, size: 16),
                          label: Text(
                            strings.markStudentBoarded,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.moderate,
                                ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => transit.removeBus(zone.id),
                          icon: const Icon(Icons.delete_outline_rounded, size: 16),
                          label: Text(
                            strings.remove,
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
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: strings.enterBus,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 120,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      final String bus = controller.text.trim();
                      if (bus.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(strings.busRequired)),
                        );
                        return;
                      }
                      transit.assignBus(zone.id, bus);
                      controller.clear();
                    },
                    child: Text(
                      strings.assign,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
