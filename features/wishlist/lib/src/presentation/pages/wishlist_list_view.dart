import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/wishlist_bloc.dart';
import '../bloc/wishlist_event.dart';
import '../bloc/wishlist_state.dart';

/// Wishlist screen UI. Requires a [WishlistBloc] above it in the tree
/// (provided by [WishlistListPage]).
class WishlistListView extends StatefulWidget {
  const WishlistListView({
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
  State<WishlistListView> createState() => _WishlistListViewState();
}

class _WishlistListViewState extends State<WishlistListView> {
  @override
  void initState() {
    super.initState();
    // Dispatched once here so rebuilds don't re-trigger loads and flicker
    // the list.
    BlocProvider.of<WishlistBloc>(context).add(WishlistLoad(widget.ownerId));
  }

  @override
  void didUpdateWidget(WishlistListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId) {
      BlocProvider.of<WishlistBloc>(context).add(WishlistLoad(widget.ownerId));
    }
  }

  Future<void> _subscribe() async {
    final subscribe = widget.onSubscribe;
    if (subscribe == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('subscribed'.tr())));
      return;
    }
    try {
      await subscribe();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('subscribed'.tr())));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${'subscribe_failed'.tr()}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isOwner ? 'my_wishlist'.tr() : 'wishlist'.tr()),
        actions: [
          if (!widget.isOwner)
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'subscribe_updates'.tr(),
              onPressed: _subscribe,
            ),
        ],
      ),
      floatingActionButton: widget.isOwner && widget.onAdd != null
          ? FloatingActionButton(
              onPressed: widget.onAdd,
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          _SyncBanner(outbox: widget.outbox, onSyncNow: widget.onSyncNow),
          Expanded(
            child: BlocBuilder<WishlistBloc, WishlistState>(
              builder: (context, state) {
                if (state.isLoading && state.items.isEmpty) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 5,
                    itemBuilder: (_, _) => const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LoadingShimmer(height: 120),
                    ),
                  );
                }
                if (state.items.isEmpty) {
                  return EmptyState(
                    title: 'no_items'.tr(),
                    subtitle: 'no_items_hint'.tr(),
                  );
                }
                return AppSkeleton(
                  enabled: state.isLoading,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.items.length,
                    itemBuilder: (context, i) {
                      final item = state.items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          onTap: () => widget.onOpenItem?.call(item.id),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item.imageUrls.isNotEmpty)
                                ItemCarousel(
                                  imageUrls: item.imageUrls,
                                  height: 160,
                                ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                  if (item.isHidden)
                                    const Icon(
                                      Icons.visibility_off,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                ],
                              ),
                              if (item.description != null)
                                Text(item.description!),
                              if (item.placeLabel != null)
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 16,
                                    ),
                                    Text(item.placeLabel!),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Pending-offline-mutations banner with a manual "sync now" action.
/// Hidden when no outbox is wired or nothing is pending.
class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.outbox, required this.onSyncNow});

  final OutboxService? outbox;
  final Future<void> Function()? onSyncNow;

  @override
  Widget build(BuildContext context) {
    final box = outbox;
    final sync = onSyncNow;
    if (box == null || sync == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: box,
      builder: (context, _) {
        final n = box.pending;
        if (n == 0) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('${'pending_sync'.tr()} ($n)')),
              TextButton(onPressed: () => sync(), child: Text('sync_now'.tr())),
            ],
          ),
        );
      },
    );
  }
}
