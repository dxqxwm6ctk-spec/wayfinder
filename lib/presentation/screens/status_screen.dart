import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_strings.dart';
import '../providers/app_settings_provider.dart';
import '../providers/transit_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell_background.dart';
import '../widgets/header_row.dart';
import '../widgets/info_card.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  String? _lastBusAssignedAlertKey;

  void _maybeShowBusAssignedAlert(TransitProvider transit, AppStrings strings) {
    final String area = transit.studentCurrentArea;
    final String? bus = transit.busForStudentArea;

    if (bus == null) {
      if (_lastBusAssignedAlertKey != null &&
          _lastBusAssignedAlertKey!.startsWith('$area|')) {
        _lastBusAssignedAlertKey = null;
      }
      return;
    }

    final String key = '$area|$bus';
    if (_lastBusAssignedAlertKey == key) {
      return;
    }
    _lastBusAssignedAlertKey = key;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${strings.busAssignedAlert}: $area (BUS #$bus)'),
        ),
      );
    });
  }

  String _lastUpdatedText(AppStrings strings, DateTime? updatedAt) {
    if (updatedAt == null) {
      return strings.etaUnavailable;
    }
    final int minutes = DateTime.now().difference(updatedAt).inMinutes;
    if (minutes <= 0) {
      return strings.justNow;
    }
    return strings.minutesAgo(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final TransitProvider transit = context.watch<TransitProvider>();
    final AppSettingsProvider settings = context.watch<AppSettingsProvider>();
    final AppStrings strings = AppStrings(isArabic: settings.isArabic);

    _maybeShowBusAssignedAlert(transit, strings);

    final String area = transit.studentCurrentArea;
    final String? bus = transit.busForStudentArea;
    final int? eta = transit.estimatedArrivalMinutesForStudentArea;
    final String rideStatus = transit.hasActiveStudentRequest
        ? strings.activeRide
        : strings.noActiveRide;
    final String areaWithBus = bus != null
        ? '$area • BUS #$bus'
        : '$area • ${strings.noBusAssignedToArea}';
    final String etaText = eta != null ? strings.etaMinutes(eta) : strings.etaUnavailable;
    final String lastUpdatedText = _lastUpdatedText(strings, transit.lastUpdatedAt);

    return Scaffold(
      body: AppShellBackground(
        child: transit.loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  HeaderRow(title: strings.appName),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.glass.withValues(alpha: 0.32)
                          : Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          strings.transitStatusTitle,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.transitStatusSubtitle,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  InfoCard(
                    title: strings.yourRideStatus,
                    value: rideStatus,
                    indicatorColor: transit.hasActiveStudentRequest
                        ? AppColors.stable
                        : const Color(0xFF4B5B78),
                  ),
                  const SizedBox(height: 14),
                  InfoCard(
                    title: strings.yourCurrentArea,
                    value: areaWithBus,
                    indicatorColor: bus != null
                        ? AppColors.accentLight
                        : const Color(0xFF4B5B78),
                  ),
                  const SizedBox(height: 14),
                  InfoCard(
                    title: strings.estimatedArrival,
                    value: etaText,
                    indicatorColor: eta != null
                        ? AppColors.accent
                        : const Color(0xFF4B5B78),
                  ),
                  const SizedBox(height: 14),
                  InfoCard(
                    title: strings.lastUpdated,
                    value: lastUpdatedText,
                    indicatorColor: const Color(0xFF4B5B78),
                  ),
                  const SizedBox(height: 14),
                  InfoCard(
                    title: strings.activeStatus,
                    value: strings.localizeSystemStatus(transit.systemStatus),
                    indicatorColor: AppColors.accentLight,
                  ),
                  const SizedBox(height: 12),
                  InfoCard(
                    title: strings.campusConnectivity,
                    value: strings.localizeCampusConnectivity(
                      transit.campusConnectivity,
                    ),
                    indicatorColor: const Color(0xFF30343C),
                  ),
                  const SizedBox(height: 12),
                  InfoCard(
                    title: strings.fleetStatus,
                    value: strings.localizeFleetStatus(transit.fleetStatus),
                    indicatorColor: AppColors.accent,
                  ),
                  const SizedBox(height: 12),
                  InfoCard(
                    title: strings.queueLoad,
                    value: strings.studentsWaitingCount(transit.waitingStudents),
                    indicatorColor: AppColors.accentLight,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
      ),
    );
  }
}
