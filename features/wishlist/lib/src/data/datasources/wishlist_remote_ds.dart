import 'package:core/core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/wishlist_item.dart';
import '../models/wishlist_item_model.dart';

class WishlistRemoteDataSource {
  WishlistRemoteDataSource(this._client);
  final SupabaseClient _client;

  /// Own items, newest last. Paginated: [limit]/[offset] keep large
  /// wishlists from DOSing the client; callers page until a short page.
  static const int fetchPageSize = 100;

  Future<List<WishlistItemModel>> fetchMine(
    String ownerId, {
    int limit = fetchPageSize,
    int offset = 0,
  }) async {
    final rows = await _client
        .from(AppConstants.wishlistItemsTable)
        .select()
        .eq('owner_id', ownerId)
        .order('created_at')
        .range(offset, offset + limit - 1);
    return (rows as List).map((e) => WishlistItemModel.fromJson(e)).toList();
  }

  /// All own items across pages (used by cache reconciliation).
  Future<List<WishlistItemModel>> fetchAllMine(String ownerId) async {
    final all = <WishlistItemModel>[];
    var offset = 0;
    while (true) {
      final page = await fetchMine(ownerId, offset: offset);
      all.addAll(page);
      if (page.length < fetchPageSize) return all;
      offset += page.length;
    }
  }

  Future<WishlistItemModel?> fetchById(String itemId) async {
    final row = await _client
        .from(AppConstants.wishlistItemsTable)
        .select()
        .eq('id', itemId)
        .maybeSingle();
    if (row == null) return null;
    return WishlistItemModel.fromJson(row);
  }

  Future<WishlistItemModel> insert(WishlistItemModel item) async {
    final row = await _client
        .from(AppConstants.wishlistItemsTable)
        .insert(item.toJson())
        .select()
        .single();
    return WishlistItemModel.fromJson(row);
  }

  Future<WishlistItemModel> update(WishlistItemModel item) async {
    final row = await _client
        .from(AppConstants.wishlistItemsTable)
        .update(item.toUpdateJson())
        .eq('id', item.id)
        .select()
        .single();
    return WishlistItemModel.fromJson(row);
  }

  /// Deletes the row, returning true when a row was actually removed.
  /// A false return means the row was already gone (or RLS denied the
  /// delete): callers must not wipe cache/storage in that case without
  /// reconciling, and must surface the failure instead of reporting success.
  Future<bool> delete(String itemId) async {
    final rows = await _client
        .from(AppConstants.wishlistItemsTable)
        .delete()
        .eq('id', itemId)
        .select('id');
    return (rows as List).isNotEmpty;
  }

  /// Uploads a device-local image for an item and returns its public URL.
  /// The path is scoped under the owner id so the `avatars` bucket RLS
  /// policy (`foldername(name)[1] == firebase_uid claim`) permits it.
  /// The filename is stable per (item, file) so a retried upload overwrites
  /// (upsert) instead of orphaning a duplicate object.
  Future<String> uploadItemImage({
    required String ownerId,
    required String itemId,
    required String filePath,
  }) => uploadToBucket(
    _client,
    bucket: AppConstants.avatarsBucket,
    path: '$ownerId/items/$itemId/${stableStorageFileName(itemId, filePath)}',
    filePath: filePath,
  );

  /// Best-effort removal of an uploaded image by its public URL. No-op for
  /// non-bucket URLs (e.g. legacy entries) so cleanup never fails a delete.
  Future<void> deleteImageByUrl(String imageUrl) => removeByUrls(
    _client,
    bucket: AppConstants.avatarsBucket,
    imageUrls: [imageUrl],
  );

  Future<void> subscribe(String subscriberId, String targetUserId) => _client
      .from(AppConstants.subscriptionsTable)
      .upsert({'subscriber_id': subscriberId, 'target_user_id': targetUserId});

  Future<void> unsubscribe(String subscriberId, String targetUserId) => _client
      .from(AppConstants.subscriptionsTable)
      .delete()
      .eq('subscriber_id', subscriberId)
      .eq('target_user_id', targetUserId);

  /// Deletes every subscription row where the user is either side.
  /// Verified with `.select()`: silent no-ops are not reported as success.
  Future<void> deleteAllSubscriptionsForUser(String userId) async {
    await _client
        .from(AppConstants.subscriptionsTable)
        .delete()
        .eq('subscriber_id', userId);
    await _client
        .from(AppConstants.subscriptionsTable)
        .delete()
        .eq('target_user_id', userId);
  }

  Future<List<Subscription>> fetchSubscriptions(String subscriberId) async {
    final rows = await _client
        .from(AppConstants.subscriptionsTable)
        .select()
        .eq('subscriber_id', subscriberId);
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(
          (m) => Subscription(
            subscriberId: m['subscriber_id'] as String? ?? subscriberId,
            targetUserId: m['target_user_id'] as String? ?? '',
            createdAt:
                DateTime.tryParse(m['created_at'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
          ),
        )
        .where((s) => s.targetUserId.isNotEmpty)
        .toList();
  }
}
