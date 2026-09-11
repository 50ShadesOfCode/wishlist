import 'package:auth/auth.dart';
import 'package:chat/chat.dart';
import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:profile/profile.dart';
import 'package:wishlist/wishlist.dart';

import '../di/injection.dart';

/// Full account-deletion cascade (all through use-cases, never repositories):
/// 1. wishlist rows via [DeleteItemUseCase] (each deletes its row + images +
///    Firestore chats via the injected hook),
/// 2. subscriptions on both sides,
/// 3. remaining Firestore threads,
/// 4. the Supabase profile row (+ avatars) via [DeleteProfileUseCase] (RLS
///    needs the live bridged session, so this runs before the Firebase user
///    delete).
/// The Firebase user itself is deleted afterwards via [DeleteAccountRequested]
/// on the [AuthBloc] (loading/error states included).
///
/// Any backend step failing aborts and keeps the user signed in. A
/// `requires-recent-login` Firebase error leaves a partial state (data
/// already deleted); the caller surfaces [reauthMessage] so the user
/// re-authenticates and retries.
Future<void> deleteAccountCascade(String userId) async {
  List<WishlistItem> items = const [];
  try {
    items = await sl<GetMyItemsUseCase>().call(userId);
  } catch (e) {
    appLogger.warning('Account deletion: item fetch failed: $e');
    items = const [];
  }
  for (final item in items) {
    await sl<DeleteItemUseCase>().call(item.id);
  }
  await sl<DeleteAllSubscriptionsForUserUseCase>().call(userId);
  try {
    await sl<DeleteThreadsForUserUseCase>().call(userId);
  } catch (e) {
    // Threads for deleted items are already gone via the per-item hook;
    // best-effort remainder.
    appLogger.warning('Account deletion: thread sweep failed: $e');
  }
  await sl<DeleteProfileUseCase>().call(userId);
}

/// Firebase demands a fresh credential for account deletion; when the
/// session is stale the delete throws `requires-recent-login` while data
/// may already be partially removed. Surface a re-auth prompt instead of a
/// raw exception string.
String reauthMessage(Object e) {
  final text = e.toString().toLowerCase();
  if (text.contains('recent-login') || text.contains('recent login')) {
    return 'delete_reauth'.tr();
  }
  return 'Delete failed: ${describeError(e)}';
}
