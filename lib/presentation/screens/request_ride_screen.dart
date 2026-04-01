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
  String? _lastBusAssignmentNotificationKey;
  String? _lastDepartedPromptKey;

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

  @override
  Widget build(BuildContext context) {
    final TransitProvider transit = context.watch<TransitProvider>();
    final AppSettingsProvider settings = context.watch<AppSettingsProvider>();
    final AppStrings strings = AppStrings(isArabic: settings.isArabic);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final RequestExecutionSummary? activeSummary = transit.activeRequestSummary;
    final RequestExecutionSummary? summaryForView =
        activeSummary ?? _lastSummary;

    _maybeNotifyBusAssigned(transit, strings);
    _maybePromptBusDeparted(transit, strings);

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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.glass.withValues(alpha: 0.28)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  strings.immediatePickup,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
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
                            activeThumbColor: isDark
                                ? AppColors.textPrimary
                                : Colors.white,
                            activeTrackColor: isDark
                                ? AppColors.accentLight
                                : AppColors.accent.withValues(alpha: 0.46),
                            inactiveTrackColor: isDark
                                ? AppColors.surfaceSoft
                                : const Color(0xFFD7DFED),
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
                          color:
                              (isDark
                                      ? AppColors.textPrimary
                                      : const Color(0xFF111827))
                                  .withValues(alpha: 0.72),
                        ),
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
                          dropdownColor: isDark
                              ? AppColors.surface
                              : Colors.white,
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
                                    style: Theme.of(context).textTheme.bodyLarge
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
                      if (!transit.hasActiveStudentRequest)
                        CustomButton(
                          label: strings.confirmRequest,
                          icon: Icons.arrow_forward,
                          onPressed: () {
                            final RequestExecutionSummary summary = transit
                                .executeImmediateRequest();
                            setState(() {
                              _lastSummary = summary;
                            });
                            final String busText =
                                summary.busNumber == null ||
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
                      if (summaryForView != null) ...<Widget>[
                        const SizedBox(height: 20),
                        InfoCard(
                          title: strings.selectedArea,
                          value: summaryForView.area,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: InfoCard(
                                title: strings.currentlyWaiting,
                                value:
                                    '${summaryForView.studentsWaiting} ${strings.students}',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InfoCard(
                                title: strings.assignedBus,
                                value:
                                    summaryForView.busNumber == null ||
                                        summaryForView.busNumber!.isEmpty
                                    ? strings.noBusAssigned
                                    : 'BUS #${summaryForView.busNumber}',
                                indicatorColor: const Color(0xFF253866),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.cancel_outlined),
                            label: Text(strings.cancelRequest),
                            onPressed: () {
                              final RequestExecutionSummary? cancelled = transit
                                  .cancelRequestForArea(summaryForView.area);

                              if (cancelled == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(strings.noActiveRequest),
                                  ),
                                );
                                return;
                              }

                              setState(() {
                                _lastSummary = null;
                                _lastBusAssignmentNotificationKey = null;
                                _lastDepartedPromptKey = null;
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${strings.requestCancelledFor(cancelled.area)} | '
                                    '${strings.currentlyWaiting}: ${cancelled.studentsWaiting} ${strings.students}',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (transit.shouldPromptStudentBoarding) ...<Widget>[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.check_circle_outline_rounded,
                              ),
                              label: Text(strings.iBoarded),
                              onPressed: () {
                                final bool ok = transit
                                    .markCurrentStudentBoarded();
                                if (!ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
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
                        ],
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
