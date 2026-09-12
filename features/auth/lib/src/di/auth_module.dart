import 'package:core/core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';

import '../data/datasources/auth_local_ds.dart';
import '../data/datasources/auth_remote_ds.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/usecases/auth_usecases.dart';
import '../presentation/bloc/auth_bloc.dart';

/// Registers one repo-backed use-case, preserving its static type.
void _reg<T extends Object>(
  GetIt sl,
  T Function(AuthRepository repo) create,
) {
  sl.registerLazySingleton(() => create(sl<AuthRepository>()));
}

/// Registers the auth data layer, use-cases and bloc. Called once from the
/// app-level [configureDependencies]; keeps data classes out of the app.
void registerAuthModule(GetIt sl) {
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSource(FirebaseAuth.instance),
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
  _reg(sl, SignInUseCase.new);
  _reg(sl, SignUpUseCase.new);
  _reg(sl, GoogleSignInUseCase.new);
  _reg(sl, AppleSignInUseCase.new);
  _reg(sl, SignOutUseCase.new);
  _reg(sl, ResetPasswordUseCase.new);
  _reg(sl, DeleteAccountUseCase.new);
  _reg(sl, GetCurrentUserUseCase.new);
  _reg(sl, ChangePasswordUseCase.new);
  // Singleton: nested go_router pages (whose builder context is NOT under
  // the parent route's provider) share it via sl().
  sl.registerLazySingleton<AuthBloc>(
    () => AuthBloc(
      getCurrentUser: sl(),
      signIn: sl(),
      signUp: sl(),
      signInWithGoogle: sl(),
      signInWithApple: sl(),
      signOut: sl(),
      sendPasswordReset: sl(),
      deleteAccount: sl(),
    ),
  );
}
