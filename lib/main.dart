import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist_app/firebase_options.dart';

import 'app.dart';
import 'di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  initLogging();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env is optional for analyze / tests.
  }
  final supabaseUrl =
      dotenv.env[AppConstants.supabaseUrlKey]?.isNotEmpty == true
      ? dotenv.env[AppConstants.supabaseUrlKey]!
      : 'https://placeholder.supabase.co';
  final supabaseKey =
      dotenv.env[AppConstants.supabaseAnonKey]?.isNotEmpty == true
      ? dotenv.env[AppConstants.supabaseAnonKey]!
      : 'placeholder-anon-key';

  await Hive.initFlutter();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Firebase options missing in dev; chat repo will fail at runtime only.
  }

  // ignore: deprecated_member_use
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

  await configureDependencies();
  try {
    await sl<NotificationService>().init();
    // Best-effort: the app works without notification permission.
    await sl<NotificationService>().requestPermissions();
  } catch (_) {}
  // Saved theme (system on first launch); failures keep the default.
  try {
    await sl<ThemeController>().load();
  } catch (_) {}
  // Pending offline count for the sync banner; failures show zero.
  try {
    await sl<OutboxService>().refresh();
  } catch (_) {}

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ru')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: await _savedLocale(),
      child: const WishlistApp(),
    ),
  );
}

Future<Locale?> _savedLocale() async {
  try {
    final code = sl<PrefsService>().localeCode;
    return code == null ? null : Locale(code);
  } catch (_) {
    return null;
  }
}
