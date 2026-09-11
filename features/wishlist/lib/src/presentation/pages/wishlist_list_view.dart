import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/wishlist_bloc.dart';
import '../bloc/wishlist_event.dart';
import '../bloc/wishlist_state.dart';
import '../widgets/sync_banner.dart';

/// Wishlist screen UI. Requires a [WishlistBloc] above it in the tree
/// (provided by [WishlistListPage]).
class WishlistListView extends StatefulWidget {
  const WishlistListView({
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('my_wishlist'.tr())),
      floatingActionButton: widget.onAdd != null
          ? FloatingActionButton(
              onPressed: widget.onAdd,
              child: const Icon(Icons.add),
            )
          : null,
      body: AppErrorListener<WishlistBloc, WishlistState>(
        errorOf: (s) => s.error,
        child: Column(
          children: [
            SyncBanner(outbox: widget.outbox, onSyncNow: widget.onSyncNow),
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
                  // Load failure with nothing cached: an explicit error +
                  // retry instead of the misleading "no items" empty state
                  // (which invited duplicate re-adds).
                  if (state.items.isEmpty) {
                    if (state.error != null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('load_failed'.tr()),
                              const SizedBox(height: 12),
                              AppButton(
                                label: 'retry'.tr(),
                                onPressed: () =>
                                    BlocProvider.of<WishlistBloc>(context).add(
                                      WishlistLoad(widget.ownerId),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return EmptyState(
                      title: 'no_items'.tr(),
                      subtitle: 'no_items_hint'.tr(),
                    );
                  }
                  // Non-empty items survive a failed refresh (old list kept,
                  // error already surfaced via AppErrorListener); pull to
                  // retry the load.
                  return AppSkeleton(
                    enabled: state.isLoading,
                    child: RefreshIndicator(
                      onRefresh: () async =>
                          BlocProvider.of<WishlistBloc>(context).add(
                            WishlistLoad(widget.ownerId),
                          ),
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
                    ),
                  );
              },
            ),
          ),
          ],
        ),
      ),
    );
  }
}
