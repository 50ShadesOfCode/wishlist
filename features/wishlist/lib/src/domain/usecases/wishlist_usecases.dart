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

/// Online-only fetch of a single item (deep-link fallback for notification
/// taps when the item isn't in the in-memory list).
class GetItemByIdUseCase implements UseCase<WishlistItem?, String> {
  GetItemByIdUseCase(this._repo);
  final WishlistRepository _repo;
  @override
  Future<WishlistItem?> call(String itemId) => _repo.getItemById(itemId);
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
  /// Deletes the item row first, then its Firestore chats (via the injected
  /// hook, so this package does not depend on the chat package).
  /// Item-first ordering guarantees a failed delete never destroys
  /// discussions while leaving the item behind: if chat cleanup throws, the
  /// item row is already gone and the error surfaces so the caller can retry
  /// the (idempotent) chat cleanup. If the item delete itself fails, chats
  /// are untouched and a retry re-attempts the whole op.
  DeleteItemUseCase(this._repo, {this.deleteChatsForItem});
  final WishlistRepository _repo;
  final Future<void> Function(String itemId)? deleteChatsForItem;

  @override
  Future<void> call(String itemId) async {
    await _repo.deleteItem(itemId);
    await deleteChatsForItem?.call(itemId);
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

class DeleteAllSubscriptionsForUserUseCase implements UseCase<void, String> {
  DeleteAllSubscriptionsForUserUseCase(this._repo);
  final WishlistRepository _repo;

  @override
  Future<void> call(String userId) =>
      _repo.deleteAllSubscriptionsForUser(userId);
}

/// Replays one queued offline op (see [OutboxService]). Keeps the app layer
/// free of data models: payload parsing lives in the owning feature.
/// Malformed payloads throw [ServerFailure] with the op key so [SyncService]
/// logs and skips them (failed ops stay queued but never starve the rest).
class ReplayWishlistOpUseCase implements UseCase<void, OutboxOperation> {
  /// [deleteChatsForItem] routes replayed deletes through the same chat
  /// cascade as online deletes (see [DeleteItemUseCase]); without it,
  /// offline deletes would leak Firestore threads.
  ReplayWishlistOpUseCase(this._repo, {this.deleteChatsForItem});
  final WishlistRepository _repo;
  final Future<void> Function(String itemId)? deleteChatsForItem;

  @override
  Future<void> call(OutboxOperation op) async {
    try {
      switch (OutboxKind.fromValue(op.kind)) {
        case OutboxKind.wishlistAdd:
          final item = WishlistItemModel.fromJson(op.payload);
          // Idempotent replay: fetch BEFORE writing. A crash between the
          // online insert and the dequeue leaves the row behind; blindly
          // inserting would fail on a duplicate key.
          final existing = await _repo.getItemById(item.id);
          if (existing == null) {
            await _repo.addItem(item);
          } else {
            await _repo.updateItem(item);
          }
        case OutboxKind.wishlistUpdate:
          final item = WishlistItemModel.fromJson(op.payload);
          // Fetch-before-update: replaying an update for a row deleted
          // elsewhere must not resurrect it as an insert.
          final existing = await _repo.getItemById(item.id);
          if (existing == null) {
            await _repo.addItem(item);
          } else {
            await _repo.updateItem(item);
          }
        case OutboxKind.wishlistDelete:
          final id = op.payload['id'];
          if (id is! String || id.isEmpty) {
            throw const FormatException('wishlist_delete op missing id');
          }
          await _repo.deleteItem(id);
          await deleteChatsForItem?.call(id);
        case OutboxKind.wishlistSubscribe:
          final (subscriberId, targetUserId) = _subscriptionIds(op);
          await _repo.subscribe(subscriberId, targetUserId);
        case OutboxKind.wishlistUnsubscribe:
          final (subscriberId, targetUserId) = _subscriptionIds(op);
          await _repo.unsubscribe(subscriberId, targetUserId);
        case OutboxKind.profileUpdate:
        case null:
          throw ServerFailure('Unknown outbox op: ${op.kind}');
      }
    } on Failure {
      rethrow;
    } catch (e) {
      // Cast/parse failures (corrupt queue entries): surface as a failure
      // with the op key so the sync log identifies the poison op; the drain
      // continues with the rest.
      throw ServerFailure('Bad wishlist op ${op.key} (${op.kind}): $e');
    }
  }

  /// Validates the two id fields shared by subscribe/unsubscribe payloads.
  (String, String) _subscriptionIds(OutboxOperation op) {
    final subscriberId = op.payload['subscriber_id'];
    final targetUserId = op.payload['target_user_id'];
    if (subscriberId is! String ||
        subscriberId.isEmpty ||
        targetUserId is! String ||
        targetUserId.isEmpty) {
      throw const FormatException('subscription op missing ids');
    }
    return (subscriberId, targetUserId);
  }
}
