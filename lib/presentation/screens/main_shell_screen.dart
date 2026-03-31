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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF040507) : const Color(0xFFFFFFFF),
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: navigation.currentIndex,
          selectedItemColor: AppColors.accentLight,
          unselectedItemColor: Colors.white.withValues(alpha: 0.38),
          selectedLabelStyle: Theme.of(context).textTheme.labelMedium,
          unselectedLabelStyle: Theme.of(context).textTheme.labelMedium,
          onTap: navigation.setIndex,
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: const Icon(Icons.accessibility_new),
              label: strings.requestTab,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.directions_bus),
              label: strings.statusTab,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person),
              label: strings.profileTab,
            ),
          ],
        ),
      ),
    );
  }
}
