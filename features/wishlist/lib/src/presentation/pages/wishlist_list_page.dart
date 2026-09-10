import 'package:core_ui/core_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/wishlist_bloc.dart';
import '../bloc/wishlist_event.dart';
import '../bloc/wishlist_state.dart';

class WishlistListPage extends StatefulWidget {
  const WishlistListPage({
    super.key,
    required this.ownerId,
    this.isOwner = true,
    this.onOpenItem,
    this.onAdd,
    this.onSubscribe,
  });

  final String ownerId;
  final bool isOwner;
  final void Function(String itemId)? onOpenItem;
  final VoidCallback? onAdd;

  /// Called when a viewer taps subscribe on someone else's list. Null hides
  /// any subscribe affordance handling (button falls back to a snackbar).
  final Future<void> Function()? onSubscribe;

  @override
  State<WishlistListPage> createState() => _WishlistListPageState();
}

class _WishlistListPageState extends State<WishlistListPage> {
  @override
  void initState() {
    super.initState();
    // Dispatched once here (not in the router builder) so rebuilds don't
    // re-trigger loads and flicker the list.
    context.read<WishlistBloc>().add(WishlistLoad(widget.ownerId));
  }

  @override
  void didUpdateWidget(WishlistListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId) {
      context.read<WishlistBloc>().add(WishlistLoad(widget.ownerId));
    }
  }

  Future<void> _subscribe() async {
    final subscribe = widget.onSubscribe;
    if (subscribe == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('subscribed'.tr())),
      );
      return;
    }
    try {
      await subscribe();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('subscribed'.tr())),
      );
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
      body: BlocBuilder<WishlistBloc, WishlistState>(
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
                          ItemCarousel(imageUrls: item.imageUrls, height: 160),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: Theme.of(
                                  context,
                                ).textTheme.titleMedium,
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
    );
  }
}
