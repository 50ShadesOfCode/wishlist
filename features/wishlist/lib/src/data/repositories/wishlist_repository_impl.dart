import 'package:core/core.dart';

import '../../domain/entities/wishlist_item.dart';
import '../../domain/repositories/wishlist_repository.dart';
import '../datasources/wishlist_remote_ds.dart';
import '../models/wishlist_item_model.dart';
import 'wishlist_media_store.dart';

class WishlistRepositoryImpl implements WishlistRepository {
  WishlistRepositoryImpl(
    this._remote,
    this._cache,
    NotificationService notifications,
    this._network,
    this._outbox,
  ) : _media = WishlistMediaStore(_remote, notifications);

  final WishlistRemoteDataSource _remote;
  final HiveCacheService _cache;
  final WishlistMediaStore _media;
  final NetworkInfo _network;
  final OutboxService _outbox;

  /// Mutations check connectivity inline so offline writes can be queued
  /// to the outbox instead of failing.

  String _scopedKey(String ownerId, String id) => '$ownerId::$id';

  bool _belongsTo(Map<String, dynamic> json, String ownerId) =>
      json['owner_id'] == ownerId;

  /// Finds a cached item by id across key schemes (scoped `$owner::$id`
  /// plus legacy bare `$id` from before per-user scoping).
  Future<(String, WishlistItemModel)?> _findCached(String itemId) async {
    for (final key in await _cache.keys()) {
      if (key is! String) continue;
      if (key == itemId || key.endsWith('::$itemId')) {
        final json = await _cache.get(key);
        if (json != null) return (key, WishlistItemModel.fromJson(json));
      }
    }
    return null;
  }

  @override
  Future<List<WishlistItem>> getMyItems(String ownerId) => cachedRead(
    network: _network,
    remote: () async {
      final items = await _remote.fetchMine(ownerId);
      await _cache.putAll({
        for (final i in items) _scopedKey(ownerId, i.id): i.toJson(),
      });
      return items;
    },
    // Filter by the row's owner_id (not just the key) so a signed-in user
    // never sees another user's cached items.
    fallback: () async {
      final cached = await _cache.getAll();
      return cached
          .where((j) => _belongsTo(j, ownerId))
          .map(WishlistItemModel.fromJson)
          .toList();
    },
  );

  @override
  Future<List<WishlistItem>> getVisibleItems(String ownerId) async {
    final all = await getMyItems(ownerId);
    return all.where((e) => !e.isHidden).toList();
  }

  @override
  Future<WishlistItem?> getItemById(String itemId) async {
    try {
      return await _remote.fetchById(itemId);
    } catch (e) {
      mapDataError(e);
    }
  }

  @override
  Future<String> uploadItemImage({
    required String ownerId,
    required String itemId,
    required String filePath,
  }) => _media.uploadItemImage(
    ownerId: ownerId,
    itemId: itemId,
    filePath: filePath,
  );

  @override
  Future<void> deleteImageByUrl(String imageUrl) =>
      _media.deleteImageByUrl(imageUrl);

  @override
  Future<WishlistItem> addItem(WishlistItem item) async {
    final model = WishlistItemModel.fromEntity(item);
    // Offline: persist to cache now, queue the insert for sync. Local
    // image paths are kept as-is and uploaded during replay.
    if (await enqueueOfflineWrite(
      network: _network,
      outbox: _outbox,
      kind: OutboxKind.wishlistAdd,
      payload: model.toJson(),
      writeCache: () =>
          _cache.put(_scopedKey(item.ownerId, item.id), model.toJson()),
    )) {
      return item;
    }
    final uploaded = <String>[];
    try {
      final urls = await _media.resolveImageUrls(item, uploaded);
      final saved = await _remote.insert(
        WishlistItemModel.fromEntity(item.copyWith(imageUrls: urls)),
      );
      await _cache.put(_scopedKey(saved.ownerId, saved.id), saved.toJson());
      try {
        // Local reminder only: never fail the save over a notification.
        await _media.notifyNewItem(saved);
      } catch (_) {
        // ignore notification failures
      }
      return saved;
    } catch (e) {
      await _media.deleteUrlsBestEffort(uploaded);
      mapDataError(e);
    }
  }

  @override
  Future<WishlistItem> updateItem(WishlistItem item) async {
    final model = WishlistItemModel.fromEntity(item);
    if (await enqueueOfflineWrite(
      network: _network,
      outbox: _outbox,
      kind: OutboxKind.wishlistUpdate,
      payload: model.toJson(),
      writeCache: () =>
          _cache.put(_scopedKey(item.ownerId, item.id), model.toJson()),
    )) {
      return item;
    }
    final uploaded = <String>[];
    try {
      final urls = await _media.resolveImageUrls(item, uploaded);
      final saved = await _remote.update(
        WishlistItemModel.fromEntity(item.copyWith(imageUrls: urls)),
      );
      await _cache.put(_scopedKey(saved.ownerId, saved.id), saved.toJson());
      // Remove images the user dropped in this edit (best-effort).
      try {
        final previous = await _remote.fetchById(item.id);
        if (previous != null) {
          final removed = previous.imageUrls
              .where(isRemoteUrl)
              .where((u) => !urls.contains(u));
          await _media.deleteUrlsBestEffort(removed);
        }
      } catch (_) {
        // ignore diff cleanup failures
      }
      return saved;
    } catch (e) {
      await _media.deleteUrlsBestEffort(uploaded);
      mapDataError(e);
    }
  }

  @override
  Future<void> deleteItem(String itemId) async {
    // Offline: drop from cache now, queue the delete for sync.
    Future<void> dropFromCache() async {
      final found = await _findCached(itemId);
      if (found != null) await _cache.delete(found.$1);
    }

    if (await enqueueOfflineWrite(
      network: _network,
      outbox: _outbox,
      kind: OutboxKind.wishlistDelete,
      payload: {'id': itemId},
      writeCache: dropFromCache,
    )) {
      return;
    }
    // NOTE: this deletes only the Supabase row + local cache. Callers must
    // also delete the item's Firestore chats (owned by DeleteItemUseCase
    // via its injected hook) or chats will leak.
    List<String> imageUrls = const [];
    try {
      final previous = await _remote.fetchById(itemId);
      imageUrls = previous?.imageUrls.where(isRemoteUrl).toList() ?? const [];
    } catch (_) {
      // proceed with row delete even if the pre-fetch fails
    }
    try {
      await _remote.delete(itemId);
    } catch (e) {
      mapDataError(e);
    }
    final found = await _findCached(itemId);
    if (found != null) await _cache.delete(found.$1);
    await _media.deleteUrlsBestEffort(imageUrls);
  }

  @override
  Future<void> setHidden(String itemId, bool hidden) async {
    final found = await _findCached(itemId);
    if (found != null) {
      // updateItem queues offline, so the cached path works without network.
      await updateItem(found.$2.copyWith(isHidden: hidden));
      return;
    }
    if (!await _network.isConnected) throw const NetworkFailure();
    // Cache miss (fresh install, other device): fetch from remote instead of
    // silently doing nothing.
    final remote = await _remote.fetchById(itemId);
    if (remote == null) {
      throw const NotFoundFailure('Wishlist item not found');
    }
    await updateItem(remote.copyWith(isHidden: hidden));
  }

  @override
  Future<void> subscribe(String subscriberId, String targetUserId) async {
    if (await enqueueOfflineWrite(
      network: _network,
      outbox: _outbox,
      kind: OutboxKind.wishlistSubscribe,
      payload: {
        'subscriber_id': subscriberId,
        'target_user_id': targetUserId,
      },
      writeCache: () async {},
    )) {
      return;
    }
    try {
      await _remote.subscribe(subscriberId, targetUserId);
    } catch (e) {
      mapDataError(e);
    }
  }

  @override
  Future<void> unsubscribe(String subscriberId, String targetUserId) async {
    if (await enqueueOfflineWrite(
      network: _network,
      outbox: _outbox,
      kind: OutboxKind.wishlistUnsubscribe,
      payload: {
        'subscriber_id': subscriberId,
        'target_user_id': targetUserId,
      },
      writeCache: () async {},
    )) {
      return;
    }
    try {
      await _remote.unsubscribe(subscriberId, targetUserId);
    } catch (e) {
      mapDataError(e);
    }
  }

  @override
  Future<List<Subscription>> mySubscriptions(String subscriberId) async {
    if (!await _network.isConnected) throw const NetworkFailure();
    try {
      return await _remote.fetchSubscriptions(subscriberId);
    } catch (e) {
      mapDataError(e);
    }
  }
}
