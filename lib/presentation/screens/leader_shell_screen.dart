import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';

import '../localization/app_strings.dart';
import '../providers/app_settings_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/transit_provider.dart';
import '../providers/unified_auth_provider.dart';
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
    final UnifiedAuthProvider unifiedAuth = context.watch<UnifiedAuthProvider>();
    final AppStrings strings = AppStrings(isArabic: settings.isArabic);
    final String displayName = unifiedAuth.currentName?.trim().isNotEmpty == true
        ? unifiedAuth.currentName!.trim()
        : 'L';
    final String? profilePhotoUrl = _normalizeImageUrl(unifiedAuth.currentPhotoUrl);
    final Uint8List? profilePhotoBytes = unifiedAuth.currentPhotoBytes;
    final ImageProvider<Object>? avatarImage = profilePhotoBytes != null
      ? MemoryImage(profilePhotoBytes)
      : (profilePhotoUrl != null ? NetworkImage(profilePhotoUrl) : null);

    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              backgroundImage: avatarImage,
              foregroundImage: avatarImage,
              child: (profilePhotoBytes == null && profilePhotoUrl == null)
                  ? Text(
                      displayName.characters.first.toUpperCase(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    )
                  : null,
            ),
          ),
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

  String? _normalizeImageUrl(String? rawUrl) {
    final String? trimmed = rawUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return null;
    }

    return trimmed;
  }
}
