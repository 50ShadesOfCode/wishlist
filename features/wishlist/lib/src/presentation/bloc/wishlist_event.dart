import 'package:equatable/equatable.dart';

import '../../domain/entities/wishlist_item.dart';

abstract class WishlistEvent extends Equatable {
  const WishlistEvent();
  @override
  List<Object?> get props => [];
}

class WishlistLoad extends WishlistEvent {
  const WishlistLoad(this.ownerId);
  final String ownerId;

  @override
  List<Object?> get props => [ownerId];
}

class WishlistAdd extends WishlistEvent {
  const WishlistAdd(this.item);
  final WishlistItem item;
}

class WishlistUpdate extends WishlistEvent {
  const WishlistUpdate(this.item);
  final WishlistItem item;
}

class WishlistDelete extends WishlistEvent {
  const WishlistDelete(this.itemId);
  final String itemId;
}

class WishlistToggleHide extends WishlistEvent {
  const WishlistToggleHide(this.itemId, this.hidden);
  final String itemId;
  final bool hidden;

  @override
  List<Object?> get props => [itemId, hidden];
}

/// Resets the bloc to its initial state. Dispatched on sign-out so the next
/// user never sees the previous user's items.
class WishlistReset extends WishlistEvent {
  const WishlistReset();
}
