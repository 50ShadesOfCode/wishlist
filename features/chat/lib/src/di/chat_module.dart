import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/datasources/chat_photo_storage.dart';
import '../data/datasources/chat_remote_ds.dart';
import '../data/repositories/chat_repository_impl.dart';
import '../domain/entities/chat_message.dart';
import '../domain/repositories/chat_repository.dart';
import '../domain/usecases/chat_usecases.dart';
import '../presentation/bloc/chat_bloc.dart';

/// Registers one repo-backed use-case, preserving its static type.
void _reg<T extends Object>(
  GetIt sl,
  T Function(ChatRepository repo) create,
) {
  sl.registerLazySingleton(() => create(sl<ChatRepository>()));
}

/// Registers the chat data layer, use-cases and bloc. Called once from the
/// app-level [configureDependencies]; keeps data classes out of the app.
///
/// [onNewMessage] is the cross-feature hook (local notifications) fired once
/// per newly-unread thread; the app passes the closure so this package never
/// imports notification plumbing.
void registerChatModule(
  GetIt sl, {
  Future<void> Function(ChatThread thread)? onNewMessage,
}) {
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
      network: sl<NetworkInfo>(),
    ),
  );
  _reg(sl, WatchThreadsUseCase.new);
  _reg(sl, WatchMessagesUseCase.new);
  _reg(sl, SendTextMessageUseCase.new);
  _reg(sl, SendPhotoMessageUseCase.new);
  _reg(sl, GetUnreadThreadsUseCase.new);
  _reg(sl, MarkThreadSeenUseCase.new);
  _reg(sl, GetOrCreateThreadUseCase.new);
  _reg(sl, DeleteChatsForItemUseCase.new);
  _reg(sl, DeleteThreadsForUserUseCase.new);
  // Singleton: nested go_router pages (list + thread sub-route) share it
  // via sl().
  sl.registerLazySingleton<ChatBloc>(
    () => ChatBloc(
      watchThreads: sl(),
      watchMessages: sl(),
      sendTextMessage: sl(),
      sendPhotoMessage: sl(),
      getUnreadThreads: sl(),
      markThreadSeen: sl(),
      onNewMessage: onNewMessage,
    ),
  );
}
