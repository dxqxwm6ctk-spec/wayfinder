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

    return Scaffold(
      body: AppShellBackground(
        child: transit.loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    HeaderRow(title: strings.academicWayfinder),
                    const SizedBox(height: 26),
                    Text(
                      strings.fleetCommandTitle,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.fleetCommandSubtitle,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 30),
                    Text(
                      strings.campusLoadingZones,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.accentLight,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ...transit.zones
                        .map((Zone zone) => _zoneCard(context, transit, zone, strings)),
                    const SizedBox(height: 10),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.card : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border(
          left: BorderSide(width: 4, color: severityColor),
        ),
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
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: zone.studentsWaiting.toString().padLeft(2, '0'),
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(fontSize: 42),
                          ),
                          TextSpan(
                            text: '  ${strings.studentsWaitingLabel}',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceSoft : const Color(0xFFEFF2F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.directions_bus, color: AppColors.accentLight),
                  const SizedBox(width: 12),
                  Text(
                    zone.assignedBus!,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => transit.removeBus(zone.id),
                    child: Text(
                      strings.remove,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.accentLight,
                          ),
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
                    decoration: InputDecoration(hintText: strings.enterBus),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 110,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      minimumSize: const Size.fromHeight(58),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
                            color: const Color(0xFF082A63),
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
