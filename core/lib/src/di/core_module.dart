import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/network_info.dart';
import '../services/notification_service.dart';
import '../services/theme_controller.dart';
import '../storage/hive_service.dart';
import '../storage/outbox_service.dart';
import '../storage/prefs_service.dart';
import '../storage/secure_storage_service.dart';
import '../constants/app_constants.dart';

/// Registers all core-owned singletons. Called once from app-level
/// [configureDependencies]. Feature modules and app-composed services
/// ([SyncService], backend clients, cross-feature hooks) register in app DI.
Future<void> registerCoreModule(GetIt sl) async {
  sl.registerLazySingleton(Connectivity.new);
  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(sl<Connectivity>()),
  );
  sl.registerLazySingleton<SecureStorageService>(
    SecureStorageService.new,
  );
  final prefs = await SharedPreferences.getInstance();
  sl.registerLazySingleton<PrefsService>(() => PrefsService(prefs));
  sl.registerLazySingleton<FlutterLocalNotificationsPlugin>(
    FlutterLocalNotificationsPlugin.new,
  );
  sl.registerLazySingleton<NotificationService>(
    () => NotificationService(sl<FlutterLocalNotificationsPlugin>()),
  );
  sl.registerLazySingleton<ThemeController>(
    () => ThemeController(sl<PrefsService>()),
  );
  sl.registerLazySingleton<OutboxService>(
    () => OutboxService(HiveCacheService(AppConstants.outboxBox)),
  );
}
