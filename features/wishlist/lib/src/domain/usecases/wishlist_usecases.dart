import 'package:core/core.dart';

// NB: replay needs payload parsing, so it imports the model. In-package
// only — data/ stays out of the barrel (see wishlist.dart).
import '../../data/models/wishlist_item_model.dart';
import '../../domain/entities/wishlist_item.dart';
import '../../domain/repositories/wishlist_repository.dart';

class GetMyItemsUseCase implements UseCase<List<WishlistItem>, String> {
  GetMyItemsUseCase(this._repo);
  final WishlistRepository _repo;
  @override
  Future<List<WishlistItem>> call(String ownerId) => _repo.getMyItems(ownerId);
}

class GetVisibleItemsUseCase implements UseCase<List<WishlistItem>, String> {
  GetVisibleItemsUseCase(this._repo);
  final WishlistRepository _repo;
  @override
  Future<List<WishlistItem>> call(String ownerId) =>
      _repo.getVisibleItems(ownerId);
}

class AddItemUseCase implements UseCase<WishlistItem, WishlistItem> {
  AddItemUseCase(this._repo);
  final WishlistRepository _repo;
  @override
  Future<WishlistItem> call(WishlistItem item) => _repo.addItem(item);
}

class UpdateItemUseCase implements UseCase<WishlistItem, WishlistItem> {
  UpdateItemUseCase(this._repo);
  final WishlistRepository _repo;
  @override
  Future<WishlistItem> call(WishlistItem item) => _repo.updateItem(item);
}

class SetHiddenParams {
  const SetHiddenParams({required this.itemId, required this.hidden});
  final String itemId;
  final bool hidden;
}

class SetHiddenUseCase implements UseCase<void, SetHiddenParams> {
  SetHiddenUseCase(this._repo);
  final WishlistRepository _repo;
  @override
  Future<void> call(SetHiddenParams params) =>
      _repo.setHidden(params.itemId, params.hidden);
}

class DeleteItemUseCase implements UseCase<void, String> {
  /// Deletes the item's Firestore chats first (via the injected hook, so
  /// this package does not depend on the chat package), then the item
  /// itself. If chat deletion fails the item is kept, so a failed delete
  /// never orphans chats or silently drops the item.
  DeleteItemUseCase(this._repo, {this.deleteChatsForItem});
  final WishlistRepository _repo;
  final Future<void> Function(String itemId)? deleteChatsForItem;

  @override
  Future<void> call(String itemId) async {
    await deleteChatsForItem?.call(itemId);
    await _repo.deleteItem(itemId);
  }
}

class SubscriptionParams {
  const SubscriptionParams({
    required this.subscriberId,
    required this.targetUserId,
  });
  final String subscriberId;
  final String targetUserId;
}

class SubscribeUseCase implements UseCase<void, SubscriptionParams> {
  SubscribeUseCase(this._repo);
  final WishlistRepository _repo;

  @override
  Future<void> call(SubscriptionParams params) => _repo.subscribe(
    params.subscriberId,
    params.targetUserId,
  );
}

class UnsubscribeUseCase implements UseCase<void, SubscriptionParams> {
  UnsubscribeUseCase(this._repo);
  final WishlistRepository _repo;

  @override
  Future<void> call(SubscriptionParams params) => _repo.unsubscribe(
    params.subscriberId,
    params.targetUserId,
  );
}

class GetSubscriptionsUseCase
    implements UseCase<List<Subscription>, String> {
  GetSubscriptionsUseCase(this._repo);
  final WishlistRepository _repo;

  @override
  Future<List<Subscription>> call(String subscriberId) =>
      _repo.mySubscriptions(subscriberId);
}

/// Replays one queued offline op (see [OutboxService]). Keeps the app layer
/// free of data models: payload parsing lives in the owning feature.
class ReplayWishlistOpUseCase implements UseCase<void, OutboxOperation> {
  ReplayWishlistOpUseCase(this._repo);
  final WishlistRepository _repo;

  @override
  Future<void> call(OutboxOperation op) async {
    final payload = op.payload;
    switch (OutboxKind.fromValue(op.kind)) {
      case OutboxKind.wishlistAdd:
        final item = WishlistItemModel.fromJson(payload);
        final existing = await _repo.getItemById(item.id);
        if (existing == null) {
          await _repo.addItem(item);
        } else {
          // Crash between insert and dequeue: update instead of failing
          // on a duplicate key.
          await _repo.updateItem(item);
        }
      case OutboxKind.wishlistUpdate:
        await _repo.updateItem(WishlistItemModel.fromJson(payload));
      case OutboxKind.wishlistDelete:
        await _repo.deleteItem(payload['id'] as String);
      case OutboxKind.wishlistSubscribe:
        await _repo.subscribe(
          payload['subscriber_id'] as String,
          payload['target_user_id'] as String,
        );
      case OutboxKind.wishlistUnsubscribe:
        await _repo.unsubscribe(
          payload['subscriber_id'] as String,
          payload['target_user_id'] as String,
        );
      case OutboxKind.profileUpdate:
      case null:
        throw ServerFailure('Unknown outbox op: ${op.kind}');
    }
  }
}
