import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/config/app_env.dart';
import 'core/services/firebase_service.dart';
import 'core/services/microsoft_auth_service.dart';
import 'data/datasources/mock_data_source.dart';
import 'data/datasources/remote/remote_api_data_source.dart';
import 'data/repositories/transit_repository_impl.dart';
import 'domain/usecases/get_transit_dashboard.dart';
import 'presentation/providers/app_settings_provider.dart';
import 'presentation/providers/navigation_provider.dart';
import 'presentation/providers/transit_provider.dart';
import 'presentation/providers/unified_auth_provider.dart';
import 'presentation/screens/main_shell_screen.dart';
import 'presentation/screens/role_selection_screen.dart';
import 'presentation/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await FirebaseService().initialize();
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // Initialize Microsoft Entra
  try {
    MicrosoftAuthService().initialize();
    if (AppEnv.canUseMicrosoftAuth) {
      MicrosoftAuthService.configure(
        clientId: AppEnv.microsoftClientId,
        redirectUrl: AppEnv.microsoftRedirectUrl,
        tenantId: AppEnv.microsoftTenantId,
      );
      debugPrint('Microsoft Entra initialized successfully');
    } else {
      debugPrint(
        'Microsoft Entra is not configured. '
        'Set MICROSOFT_CLIENT_ID and MICROSOFT_TENANT_ID via --dart-define.',
      );
    }
  } catch (e) {
    debugPrint('Microsoft Entra initialization failed: $e');
  }

  runApp(const WayfinderApp());
}

class WayfinderApp extends StatelessWidget {
  const WayfinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    final MockDataSource dataSource = MockDataSource();
    final RemoteApiDataSource? remoteDataSource = AppEnv.canUseRemote
        ? RemoteApiDataSource(baseUrl: AppEnv.apiBaseUrl)
        : null;

    final TransitRepositoryImpl transitRepository = TransitRepositoryImpl(
      dataSource,
      remoteApiDataSource: remoteDataSource,
    );

    // Initialize services
    final FirebaseService firebaseService = FirebaseService();
    final MicrosoftAuthService microsoftAuthService = MicrosoftAuthService();

    return MultiProvider(
      providers: <ChangeNotifierProvider<dynamic>>[
        ChangeNotifierProvider<AppSettingsProvider>(
          create: (_) => AppSettingsProvider(),
        ),
        ChangeNotifierProvider<UnifiedAuthProvider>(
          create: (_) => UnifiedAuthProvider(
            firebaseService: firebaseService,
            microsoftAuthService: microsoftAuthService,
          ),
        ),
        ChangeNotifierProvider<TransitProvider>(
          create: (_) => TransitProvider(GetTransitDashboard(transitRepository)),
        ),
        ChangeNotifierProvider<NavigationProvider>(
          create: (_) => NavigationProvider(),
        ),
      ],
      child: Consumer<AppSettingsProvider>(
        builder: (BuildContext context, AppSettingsProvider settings, Widget? child) {
          return MaterialApp(
            title: 'WAYFINDER',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: settings.themeMode,
            locale: settings.locale,
            supportedLocales: const <Locale>[
              Locale('en'),
              Locale('ar'),
            ],
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routes: <String, WidgetBuilder>{
              '/main': (_) => const MainShellScreen(),
            },
            home: const RoleSelectionScreen(),
          );
        },
      ),
    );
  }
}
