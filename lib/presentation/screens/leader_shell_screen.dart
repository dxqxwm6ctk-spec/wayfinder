import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_strings.dart';
import '../providers/app_settings_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/transit_provider.dart';
import 'fleet_management_screen.dart';
import 'role_selection_screen.dart';

class LeaderShellScreen extends StatefulWidget {
  const LeaderShellScreen({super.key});

  @override
  State<LeaderShellScreen> createState() => _LeaderShellScreenState();
}

class _LeaderShellScreenState extends State<LeaderShellScreen> {
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.leaderSignedOut)),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransitProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppSettingsProvider settings = context.watch<AppSettingsProvider>();
    final AppStrings strings = AppStrings(isArabic: settings.isArabic);

    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          TextButton.icon(
            onPressed: _logoutLeader,
            icon: const Icon(Icons.logout_rounded),
            label: Text(strings.leaderSignOut),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: const FleetManagementScreen(),
    );
  }
}
