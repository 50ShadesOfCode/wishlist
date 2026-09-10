import 'package:core/core.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/datasources/profile_remote_ds.dart';
import '../data/repositories/profile_repository_impl.dart';
import '../domain/repositories/profile_repository.dart';
import '../domain/usecases/profile_usecases.dart';
import '../presentation/bloc/profile_bloc.dart';

/// Registers one repo-backed use-case, preserving its static type.
void _reg<T extends Object>(
  GetIt sl,
  T Function(ProfileRepository repo) create,
) {
  sl.registerLazySingleton(() => create(sl<ProfileRepository>()));
}

/// Registers the profile data layer, use-cases and bloc. Called once from
/// the app-level [configureDependencies]; keeps data classes out of the app.
void registerProfileModule(GetIt sl) {
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(
      sl<ProfileRemoteDataSource>(),
      HiveCacheService(AppConstants.profileCacheBox),
      sl<NetworkInfo>(),
      sl<OutboxService>(),
    ),
  );
  _reg(sl, GetProfileUseCase.new);
  _reg(sl, UpdateProfileUseCase.new);
  _reg(sl, UploadAvatarUseCase.new);
  _reg(sl, RemoveAvatarUseCase.new);
  _reg(sl, IsUsernameTakenUseCase.new);
  _reg(sl, DeleteProfileUseCase.new);
  _reg(sl, ReplayProfileOpUseCase.new);
  // Singleton: nested go_router pages share it via sl().
  sl.registerLazySingleton<ProfileBloc>(
    () => ProfileBloc(
      getProfile: sl(),
      updateProfile: sl(),
      uploadAvatar: sl(),
      removeAvatar: sl(),
      isUsernameTaken: sl(),
    ),
  );
}
