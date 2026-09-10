import 'package:equatable/equatable.dart';

import '../../domain/entities/wishlist_item.dart';

abstract class WishlistEvent extends Equatable {
  const WishlistEvent();
  @override
  List<Object?> get props => [];
}

class WishlistLoad extends WishlistEvent {
  const WishlistLoad(this.ownerId, {this.visibleOnly = false});
  final String ownerId;
  final bool visibleOnly;
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
  const WishlistToggleHide(this.itemId, this.hidden, {required this.ownerId});
  final String itemId;
  final bool hidden;

  /// Owner to reload after the toggle. Carried explicitly because the list
  /// may be empty (deriving it from `state.items.first` is unreliable).
  final String ownerId;

  @override
  List<Object?> get props => [itemId, hidden, ownerId];
}
