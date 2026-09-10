import 'package:core/core.dart';

import '../../domain/entities/wishlist_item.dart';
import '../datasources/wishlist_remote_ds.dart';

/// Image upload/removal + new-item notifications for wishlist items.
/// Extracted from [WishlistRepositoryImpl] to keep it focused on
/// CRUD, cache and outbox concerns.
class WishlistMediaStore {
  WishlistMediaStore(this._remote, this._notifications);

  final WishlistRemoteDataSource _remote;
  final NotificationService _notifications;

  Future<void> notifyNewItem(WishlistItem item) =>
      _notifications.showNewItem(
        itemId: item.id,
        title: 'New wishlist item',
        body: '${item.name} was added',
      );

  Future<String> uploadItemImage({
    required String ownerId,
    required String itemId,
    required String filePath,
  }) => _remote.uploadItemImage(
    ownerId: ownerId,
    itemId: itemId,
    filePath: filePath,
  );

  Future<void> deleteImageByUrl(String imageUrl) =>
      _remote.deleteImageByUrl(imageUrl);

  /// Uploads any device-local image paths, returning public URLs.
  /// [uploaded] collects the new URLs so callers can roll them back if a
  /// later step (e.g. row insert) fails.
  Future<List<String>> resolveImageUrls(
    WishlistItem item,
    List<String> uploaded,
  ) async {
    final urls = <String>[];
    for (final path in item.imageUrls) {
      if (isRemoteUrl(path)) {
        urls.add(path);
        continue;
      }
      final url = await uploadItemImage(
        ownerId: item.ownerId,
        itemId: item.id,
        filePath: path,
      );
      uploaded.add(url);
      urls.add(url);
    }
    return urls;
  }

  Future<void> deleteUrlsBestEffort(Iterable<String> urls) async {
    for (final url in urls) {
      try {
        await deleteImageByUrl(url);
      } catch (_) {
        // Cleanup must never fail the user-facing operation.
      }
    }
  }
}
