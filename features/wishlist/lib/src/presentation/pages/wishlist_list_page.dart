import 'package:core/core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../bloc/wishlist_bloc.dart';
import 'wishlist_list_view.dart';

/// Provides the shared [WishlistBloc] singleton and renders
/// [WishlistListView]. Keeps BlocProvider wiring out of the router.
class WishlistListPage extends StatelessWidget {
  const WishlistListPage({
    super.key,
    required this.ownerId,
    this.isOwner = true,
    this.onOpenItem,
    this.onAdd,
    this.onSubscribe,
    this.outbox,
    this.onSyncNow,
  });

  final String ownerId;
  final bool isOwner;
  final void Function(String itemId)? onOpenItem;
  final VoidCallback? onAdd;

  /// Called when a viewer taps subscribe on someone else's list. Null hides
  /// any subscribe affordance handling (button falls back to a snackbar).
  final Future<void> Function()? onSubscribe;

  /// Offline outbox (pending count drives the sync banner) and manual sync.
  /// Both null hides the banner. Wired by the app router.
  final OutboxService? outbox;
  final Future<void> Function()? onSyncNow;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: GetIt.instance<WishlistBloc>(),
      child: WishlistListView(
        ownerId: ownerId,
        isOwner: isOwner,
        onOpenItem: onOpenItem,
        onAdd: onAdd,
        onSubscribe: onSubscribe,
        outbox: outbox,
        onSyncNow: onSyncNow,
      ),
    );
  }
}
