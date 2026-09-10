import 'package:auth/auth.dart';
import 'package:chat/chat.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:profile/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/wishlist.dart';

import '../services/notification_service.dart';
import '../services/supabase_session_bridge.dart';
import '../services/theme_controller.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  await registerCoreModule(sl);

  sl.registerLazySingleton<FlutterLocalNotificationsPlugin>(
    FlutterLocalNotificationsPlugin.new,
  );
  sl.registerLazySingleton<NotificationService>(
    () => NotificationService(sl<FlutterLocalNotificationsPlugin>()),
  );
  sl.registerLazySingleton<ThemeController>(
    () => ThemeController(sl<PrefsService>()),
  );

  // Supabase must be initialized before this (see main.dart).
  final supabase = Supabase.instance.client;
  sl.registerLazySingleton<SupabaseClient>(() => supabase);
  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  // Exchanges the Firebase ID token for a Supabase session (RLS identity).
  sl.registerLazySingleton<SupabaseSessionBridge>(
    () => SupabaseSessionBridge(supabase, FirebaseAuth.instance),
  );

  // Auth (Firebase; Supabase client below is for DB tables only)
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSource(FirebaseAuth.instance, GoogleSignIn()),
  );
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSource(
      HiveCacheService(AppConstants.authCacheBox),
      sl<SecureStorageService>(),
    ),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      sl<AuthRemoteDataSource>(),
      sl<AuthLocalDataSource>(),
    ),
  );
  // Blocs are singletons so nested go_router pages (whose builder context
  // is NOT under the parent route's provider) can share them via sl().
  sl.registerLazySingleton<AuthBloc>(() => AuthBloc(sl<AuthRepository>()));

  // Profile
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(
      sl<ProfileRemoteDataSource>(),
      HiveCacheService(AppConstants.profileCacheBox),
      sl<NetworkInfo>(),
    ),
  );
  sl.registerLazySingleton<ProfileBloc>(
    () => ProfileBloc(sl<ProfileRepository>()),
  );

  // Wishlist
  sl.registerLazySingleton<WishlistRemoteDataSource>(
    () => WishlistRemoteDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<WishlistRepository>(
    () => WishlistRepositoryImpl(
      sl<WishlistRemoteDataSource>(),
      HiveCacheService(AppConstants.wishlistCacheBox),
      sl<FlutterLocalNotificationsPlugin>(),
      sl<NetworkInfo>(),
    ),
  );
  sl.registerLazySingleton<WishlistBloc>(
    () => WishlistBloc(
      sl<WishlistRepository>(),
      deleteChatsForItem: sl<ChatRepository>().deleteChatsForItem,
    ),
  );

  // Chat (Firestore threads/messages; Supabase Storage for photo uploads)
  sl.registerLazySingleton<ChatRemoteDataSource>(
    () => ChatRemoteDataSource(sl<FirebaseFirestore>()),
  );
  sl.registerLazySingleton<ChatPhotoStorage>(
    () => ChatPhotoStorage(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(
      sl<ChatRemoteDataSource>(),
      photoStorage: sl<ChatPhotoStorage>(),
    ),
  );
  sl.registerLazySingleton<ChatBloc>(() => ChatBloc(sl<ChatRepository>()));
}
