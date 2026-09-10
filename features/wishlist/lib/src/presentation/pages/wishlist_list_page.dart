import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../bloc/wishlist_bloc.dart';
import 'wishlist_list_view.dart';

/// Provides the shared [WishlistBloc] singleton and renders
/// [WishlistListView]. Keeps BlocProvider wiring out of the router.
class WishlistListPage extends StatelessWidget {
  const WishlistListPage({
    super.key,
    required this.ownerId,
    this.onOpenItem,
    this.onAdd,
    this.outbox,
    this.onSyncNow,
  });

  final String ownerId;
  final void Function(String itemId)? onOpenItem;
  final VoidCallback? onAdd;

  /// Offline outbox (pending count drives the sync banner) and manual sync.
  /// Both null hides the banner. Wired by the app router.
  final OutboxService? outbox;
  final Future<void> Function()? onSyncNow;

  @override
  Widget build(BuildContext context) {
    return ProvideBloc<WishlistBloc>(
      child: WishlistListView(
        ownerId: ownerId,
        onOpenItem: onOpenItem,
        onAdd: onAdd,
        outbox: outbox,
        onSyncNow: onSyncNow,
      ),
    );
  }
}
