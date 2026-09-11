import 'package:core/core.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/datasources/wishlist_remote_ds.dart';
import '../data/repositories/wishlist_repository_impl.dart';
import '../domain/repositories/wishlist_repository.dart';
import '../domain/usecases/wishlist_usecases.dart';
import '../presentation/bloc/wishlist_bloc.dart';

/// Registers one repo-backed use-case, preserving its static type.
void _reg<T extends Object>(
  GetIt sl,
  T Function(WishlistRepository repo) create,
) {
  sl.registerLazySingleton(() => create(sl<WishlistRepository>()));
}

/// Registers the wishlist data layer, use-cases and bloc. Called once from
/// the app-level [configureDependencies]; keeps data classes out of the app.
///
/// [deleteChatsForItem] is the cross-feature hook (chat package) owned by
/// [DeleteItemUseCase]; the app passes the tear-off so this package never
/// imports chat.
void registerWishlistModule(
  GetIt sl, {
  Future<void> Function(String itemId)? deleteChatsForItem,
}) {
  // The same hook serves online deletes and replayed offline deletes.
  sl.registerLazySingleton<WishlistRemoteDataSource>(
    () => WishlistRemoteDataSource(sl<SupabaseClient>()),
  );
  sl.registerLazySingleton<WishlistRepository>(
    () => WishlistRepositoryImpl(
      sl<WishlistRemoteDataSource>(),
      HiveCacheService(AppConstants.wishlistCacheBox),
      sl<NotificationService>(),
      sl<NetworkInfo>(),
      sl<OutboxService>(),
    ),
  );
  _reg(sl, GetMyItemsUseCase.new);
  _reg(sl, GetVisibleItemsUseCase.new);
  _reg(sl, GetItemByIdUseCase.new);
  _reg(sl, AddItemUseCase.new);
  _reg(sl, UpdateItemUseCase.new);
  sl.registerLazySingleton(
    () => DeleteItemUseCase(
      sl<WishlistRepository>(),
      deleteChatsForItem: deleteChatsForItem,
    ),
  );
  _reg(sl, SetHiddenUseCase.new);
  _reg(sl, SubscribeUseCase.new);
  _reg(sl, UnsubscribeUseCase.new);
  _reg(sl, GetSubscriptionsUseCase.new);
  _reg(sl, DeleteAllSubscriptionsForUserUseCase.new);
  sl.registerLazySingleton(
    () => ReplayWishlistOpUseCase(
      sl<WishlistRepository>(),
      deleteChatsForItem: deleteChatsForItem,
    ),
  );
  // Singleton: nested go_router pages (list + edit sub-route) share it
  // via sl().
  sl.registerLazySingleton<WishlistBloc>(
    () => WishlistBloc(
      getMyItems: sl(),
      addItem: sl(),
      updateItem: sl(),
      deleteItem: sl(),
      setHidden: sl(),
    ),
  );
}
