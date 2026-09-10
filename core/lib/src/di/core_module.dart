import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/network_info.dart';
import '../storage/local_db_service.dart';
import '../storage/prefs_service.dart';
import '../storage/secure_storage_service.dart';

/// Registers core singletons. Called from app-level injection.
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
  sl.registerLazySingleton<LocalDbService>(InMemoryLocalDbService.new);
}
