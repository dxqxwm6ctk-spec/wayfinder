import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_strings.dart';
import '../providers/app_settings_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/transit_provider.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';
import 'request_ride_screen.dart';
import 'status_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  final List<Widget> _pages = const <Widget>[
    RequestRideScreen(),
    StatusScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransitProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final NavigationProvider navigation = context.watch<NavigationProvider>();
    final AppSettingsProvider settings = context.watch<AppSettingsProvider>();
    final AppStrings strings = AppStrings(isArabic: settings.isArabic);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 340),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey<int>(navigation.currentIndex),
          child: _pages[navigation.currentIndex],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.glass.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.14),
                blurRadius: 24,
                spreadRadius: -10,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.transparent,
              elevation: 0,
              indicatorColor: isDark
                  ? AppColors.accent.withValues(alpha: 0.24)
                  : AppColors.accent.withValues(alpha: 0.14),
              labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
                (Set<WidgetState> states) {
                  final bool selected = states.contains(WidgetState.selected);
                  return Theme.of(context).textTheme.labelMedium!.copyWith(
                    color: selected
                        ? (isDark ? AppColors.accentLight : AppColors.accent)
                        : (isDark ? AppColors.textMuted : const Color(0xFF6D7B94)),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  );
                },
              ),
            ),
            child: NavigationBar(
              selectedIndex: navigation.currentIndex,
              onDestinationSelected: navigation.setIndex,
              destinations: <NavigationDestination>[
                NavigationDestination(
                  icon: const Icon(Icons.route_outlined),
                  selectedIcon: const Icon(Icons.route),
                  label: strings.requestTab,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.directions_bus_filled_outlined),
                  selectedIcon: const Icon(Icons.directions_bus_filled),
                  label: strings.statusTab,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person_outline_rounded),
                  selectedIcon: const Icon(Icons.person_rounded),
                  label: strings.profileTab,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
