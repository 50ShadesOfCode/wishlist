import 'package:auth/auth.dart';
import 'package:chat/chat.dart';
import 'package:core_ui/core_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wishlist/wishlist.dart';

import '../di/injection.dart';

/// Opens the secret chat for [item], creating the thread on first use.
/// Shared by the wishlist edit page and the following feed.
Future<void> openItemChat(
  BuildContext context,
  AuthBloc authBloc,
  WishlistItem item,
) async {
  final me = authBloc.state.user?.id;
  if (me == null) return;
  try {
    final thread = await sl<GetOrCreateThreadUseCase>().call(
      GetOrCreateThreadParams(
        wishlistItemId: item.id,
        wishlistItemName: item.name,
        ownerId: item.ownerId,
        participantId: me,
      ),
    );
    if (context.mounted) {
      context.push('/chats/${thread.id}');
    }
  } catch (e) {
    if (context.mounted) {
      showAppSnack(context, '${'chat_open_failed'.tr()}: $e');
    }
  }
}
