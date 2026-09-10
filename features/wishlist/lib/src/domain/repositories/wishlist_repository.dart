import '../entities/wishlist_item.dart';

abstract class WishlistRepository {
  Future<List<WishlistItem>> getMyItems(String ownerId);
  Future<List<WishlistItem>> getVisibleItems(String ownerId);
  Future<WishlistItem?> getItemById(String itemId);
  Future<WishlistItem> addItem(WishlistItem item);
  Future<WishlistItem> updateItem(WishlistItem item);
  Future<void> deleteItem(String itemId);
  Future<void> setHidden(String itemId, bool hidden);

  /// Uploads a device-local image and returns its public URL.
  Future<String> uploadItemImage({
    required String ownerId,
    required String itemId,
    required String filePath,
  });

  /// Best-effort removal of an uploaded image by public URL.
  Future<void> deleteImageByUrl(String imageUrl);

  Future<void> subscribe(String subscriberId, String targetUserId);
  Future<void> unsubscribe(String subscriberId, String targetUserId);
  Future<List<Subscription>> mySubscriptions(String subscriberId);
  Stream<List<WishlistItem>> watchUserItems(String ownerId);
}
