import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_strings.dart';
import '../providers/app_settings_provider.dart';
import '../providers/transit_provider.dart';
import 'fleet_management_screen.dart';

class LeaderShellScreen extends StatefulWidget {
  const LeaderShellScreen({super.key});

  @override
  State<LeaderShellScreen> createState() => _LeaderShellScreenState();
}

class _LeaderShellScreenState extends State<LeaderShellScreen> {
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
      body: const FleetManagementScreen(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
        },
        label: Text(strings.back),
        icon: const Icon(Icons.logout_rounded),
      ),
    );
  }
}
