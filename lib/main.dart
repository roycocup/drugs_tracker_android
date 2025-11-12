import 'dart:async';
import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'database/database_helper.dart';
import 'firebase_options.dart';
import 'screens/drug_tracker_home.dart';
import 'services/user_identity_service.dart';
import 'theme/app_theme.dart';

FirebaseAnalytics? _analytics;
bool _crashlyticsAvailable = false;

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await _initializeObservability();
      final identity = await UserIdentityService.instance.getOrCreateIdentity();
      await DatabaseHelper.instance.configureForUser(identity.userId);
      runApp(MyApp(initialIdentity: identity));
    },
    (error, stack) {
      if (_crashlyticsAvailable) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } else if (kDebugMode) {
        debugPrint('Unhandled zone error: $error');
        debugPrintStack(stackTrace: stack);
      }
    },
  );
}

Future<void> _initializeObservability() async {
  if (!AppConfig.enableCrashReporting && !AppConfig.enableAnalytics) {
    return;
  }

  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (Firebase.apps.isEmpty) {
      if (options != null) {
        await Firebase.initializeApp(options: options);
      } else {
        await Firebase.initializeApp();
      }
    }

    if (AppConfig.enableCrashReporting) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      _crashlyticsAvailable = true;
    }

    if (AppConfig.enableAnalytics) {
      _analytics = FirebaseAnalytics.instance;
      await _analytics!.setAnalyticsCollectionEnabled(true);
    }
  } catch (error, stack) {
    debugPrint('Firebase initialization skipped: $error');
    if (kDebugMode) {
      debugPrintStack(stackTrace: stack);
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.initialIdentity});

  final UserIdentity initialIdentity;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drug Tracker',
      theme: AppTheme.buildTheme(),
      debugShowCheckedModeBanner: false,
      navigatorObservers: [
        if (_analytics != null)
          FirebaseAnalyticsObserver(analytics: _analytics!),
      ],
      home: DrugTrackerHome(initialIdentity: initialIdentity),
    );
  }
}
