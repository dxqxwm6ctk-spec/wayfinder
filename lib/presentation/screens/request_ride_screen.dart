import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_strings.dart';
import '../providers/app_settings_provider.dart';
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
  RequestExecutionSummary? _lastSummary;

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
                    Text(
                      strings.onDemandTransit,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.accentLight,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.requestRide,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      strings.requestSubtitle,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surface : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  strings.immediatePickup,
                                  style: Theme.of(context).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  strings.priorityDispatch,
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            activeThumbColor: AppColors.textPrimary,
                            activeTrackColor: AppColors.accentLight,
                            inactiveTrackColor: AppColors.surfaceSoft,
                            value: transit.immediatePickup,
                            onChanged: (bool value) {
                              transit.toggleImmediatePickup(value);
                              if (!value) {
                                setState(() {
                                  _lastSummary = null;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!transit.immediatePickup)
                      InfoCard(
                        title: strings.immediatePickup,
                        value: strings.turnOnImmediateHint,
                        indicatorColor: const Color(0xFF30343C),
                      )
                    else ...<Widget>[
                      Text(
                        strings.pickupArea,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: (isDark
                                      ? AppColors.textPrimary
                                      : const Color(0xFF111827))
                                  .withValues(alpha: 0.72),
                            ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceSoft : const Color(0xFFEFF2F8),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: DropdownButtonFormField<String>(
                          initialValue: transit.selectedPickupArea,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          dropdownColor: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          style: Theme.of(context).textTheme.headlineMedium,
                          decoration: const InputDecoration(border: InputBorder.none),
                          items: transit.pickupAreas
                              .map(
                                (String area) => DropdownMenuItem<String>(
                                  value: area,
                                  child: Text(area),
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
                      CustomButton(
                        label: strings.executeRequest,
                        icon: Icons.arrow_forward,
                        onPressed: () {
                          final RequestExecutionSummary summary =
                              transit.executeImmediateRequest();
                          setState(() {
                            _lastSummary = summary;
                          });
                          final String busText = summary.busNumber == null ||
                                  summary.busNumber!.trim().isEmpty
                              ? strings.noBusAssigned
                              : 'BUS #${summary.busNumber}';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${strings.selectedArea}: ${summary.area} | '
                                '${strings.currentlyWaiting}: ${summary.studentsWaiting} ${strings.students} | '
                                '${strings.assignedBus}: $busText',
                              ),
                            ),
                          );
                        },
                      ),
                      if (_lastSummary != null) ...<Widget>[
                        const SizedBox(height: 20),
                        InfoCard(
                          title: strings.selectedArea,
                          value: _lastSummary!.area,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: InfoCard(
                                title: strings.currentlyWaiting,
                                value:
                                    '${_lastSummary!.studentsWaiting} ${strings.students}',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InfoCard(
                                title: strings.assignedBus,
                                value: _lastSummary!.busNumber == null ||
                                        _lastSummary!.busNumber!.isEmpty
                                    ? strings.noBusAssigned
                                    : 'BUS #${_lastSummary!.busNumber}',
                                indicatorColor: const Color(0xFF253866),
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
  }
}
