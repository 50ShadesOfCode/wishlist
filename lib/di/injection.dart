import 'package:auth/auth.dart';
import 'package:chat/chat.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:profile/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wishlist/wishlist.dart';

import '../services/supabase_session_bridge.dart';
import '../services/sync_service.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  await registerCoreModule(sl);

  sl.registerLazySingleton<SyncService>(
    () => SyncService(
      sl<OutboxService>(),
      {
        OutboxScope.wishlist: sl<ReplayWishlistOpUseCase>(),
        OutboxScope.profile: sl<ReplayProfileOpUseCase>(),
      },
      sl<NetworkInfo>(),
    ),
  );

  // Supabase must be initialized before this (see main.dart).
  final supabase = Supabase.instance.client;
  sl.registerLazySingleton<SupabaseClient>(() => supabase);
  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  // Exchanges the Firebase ID token for a Supabase session (RLS identity).
  sl.registerLazySingleton<SupabaseSessionBridge>(
    () => SupabaseSessionBridge(supabase, FirebaseAuth.instance),
  );

  // Feature modules own their data layer (see register*Module in each
  // package barrel). The app only wires the two cross-feature hooks:
  // chat deletion for item deletes, and new-message notifications.
  //
  // GetIt split (do not mix up):
  // - App code (`lib/`) resolves via this file's `sl` alias.
  // - Feature code must use `GetIt.instance<X>()` directly: importing the
  //   app's `sl` alias from a feature package would be a pub dependency
  //   cycle (features never depend on the app).
  // - Domain work goes through use-cases (`sl<XUseCase>()`), never
  //   `sl<XRepository>` — the delete-cascade hook below resolves the chat
  //   use-case for exactly this reason.
  registerAuthModule(sl);
  registerProfileModule(sl);
  registerChatModule(
    sl,
    onNewMessage: (thread) => sl<NotificationService>().showNewMessage(
      chatId: thread.id,
      title: thread.wishlistItemName.isNotEmpty
          ? thread.wishlistItemName
          : 'Secret discussion',
      body: thread.lastMessageText ?? 'New message',
    ),
  );
  registerWishlistModule(
    sl,
    // Via use-case (never sl<ChatRepository> here): chat registers above.
    deleteChatsForItem: (id) => sl<DeleteChatsForItemUseCase>().call(id),
  );
}
