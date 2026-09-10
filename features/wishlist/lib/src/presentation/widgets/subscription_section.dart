import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/entities/wishlist_item.dart';

/// Loaded content for one followed user: display name plus visible items.
class TargetSection {
  const TargetSection({
    required this.subscription,
    required this.name,
    required this.items,
  });

  final Subscription subscription;
  final String name;
  final List<WishlistItem> items;
}

/// Header row for one followed user: avatar initial, name, unfollow action.
class SubscriptionSectionHeader extends StatelessWidget {
  const SubscriptionSectionHeader({
    super.key,
    required this.name,
    required this.onUnfollow,
  });

  final String name;
  final VoidCallback onUnfollow;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(name, style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton(
          tooltip: 'unfollow'.tr(),
          icon: const Icon(Icons.person_remove_outlined),
          onPressed: onUnfollow,
        ),
      ],
    );
  }
}
