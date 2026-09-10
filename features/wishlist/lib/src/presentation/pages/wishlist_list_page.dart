import 'package:core_ui/core_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/wishlist_bloc.dart';
import '../bloc/wishlist_state.dart';

class WishlistListPage extends StatelessWidget {
  const WishlistListPage({
    super.key,
    required this.ownerId,
    this.isOwner = true,
    this.onOpenItem,
    this.onAdd,
  });

  final String ownerId;
  final bool isOwner;
  final void Function(String itemId)? onOpenItem;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isOwner ? 'My wishlist' : 'Wishlist'),
        actions: [
          if (!isOwner)
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'Subscribe to updates',
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Subscribed to updates')),
              ),
            ),
        ],
      ),
      floatingActionButton: isOwner && onAdd != null
          ? FloatingActionButton(onPressed: onAdd, child: const Icon(Icons.add))
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
            return const EmptyState(
              title: 'No items yet',
              subtitle: 'Add your first wish to start your wishlist.',
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
                    onTap: () => onOpenItem?.call(item.id),
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
