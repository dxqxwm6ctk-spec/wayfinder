import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../providers/unified_auth_provider.dart';
import 'leader_web_screen.dart';
import 'leader_shell_screen.dart';
import 'main_shell_screen.dart';
import 'role_selection_screen.dart';

class AuthWrapperScreen extends StatelessWidget {
  const AuthWrapperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final UnifiedAuthProvider auth = context.watch<UnifiedAuthProvider>();

    // Still loading auth state
    if (!auth.isAuthStateReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // User is authenticated - wait for profile role if still loading.
    if (auth.isAuthenticated) {
      if (auth.isProfileLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      final String role = (auth.studentRole ?? '').trim().toLowerCase();
      if (role == 'leader') {
        return kIsWeb ? const LeaderWebScreen() : const LeaderShellScreen();
      }

      return const MainShellScreen();
    }

    // Not authenticated - show role selection
    return const RoleSelectionScreen();
  }
}
