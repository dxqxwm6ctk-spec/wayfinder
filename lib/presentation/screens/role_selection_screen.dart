import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_strings.dart';
import '../providers/app_settings_provider.dart';
import '../widgets/app_shell_background.dart';
import '../widgets/custom_button.dart';
import 'auth_method_selection_screen.dart';
import 'leader_login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  Route<void> _slideRoute(Widget page) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (BuildContext context, Animation<double> animation,
              Animation<double> secondaryAnimation) =>
          page,
      transitionsBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppSettingsProvider settings = context.watch<AppSettingsProvider>();
    final AppStrings strings = AppStrings(isArabic: settings.isArabic);

    return Scaffold(
      body: AppShellBackground(
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                ChoiceChip(
                  label: Text(strings.languageEnglish),
                  selected: settings.language == AppLanguage.english,
                  onSelected: (_) => settings.setLanguage(AppLanguage.english),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(strings.languageArabic),
                  selected: settings.language == AppLanguage.arabic,
                  onSelected: (_) => settings.setLanguage(AppLanguage.arabic),
                ),
                const Spacer(),
                IconButton.filledTonal(
                  onPressed: settings.toggleTheme,
                  icon: Icon(
                    settings.isDarkMode
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              strings.roleSelectionTitle,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 10),
            Text(
              strings.roleSelectionSubtitle,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 28),
            CustomButton(
              label: strings.continueAsStudent,
              onPressed: () {
                Navigator.of(context).push(_slideRoute(const AuthMethodSelectionScreen()));
              },
            ),
            const SizedBox(height: 14),
            CustomButton(
              label: strings.continueAsLeader,
              filled: false,
              onPressed: () {
                Navigator.of(context).push(_slideRoute(const LeaderLoginScreen()));
              },
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
