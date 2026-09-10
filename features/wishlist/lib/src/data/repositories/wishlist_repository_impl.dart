import 'package:core/core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/wishlist_item.dart';
import '../../domain/repositories/wishlist_repository.dart';
import '../datasources/wishlist_remote_ds.dart';
import '../models/wishlist_item_model.dart';

class WishlistRepositoryImpl implements WishlistRepository {
  WishlistRepositoryImpl(
    this._remote,
    this._cache,
    this._notifications,
    this._network,
  );

  final WishlistRemoteDataSource _remote;
  final HiveCacheService _cache;
  final FlutterLocalNotificationsPlugin _notifications;
  final NetworkInfo _network;

  /// Maps backend errors to the [Failure] taxonomy. Unknown/programming
  /// errors are wrapped as [ServerFailure] so blocs can rely on
  /// `on Failure` instead of formatting raw exceptions.
  Never _asFailure(Object e) {
    if (e is Failure) throw e;
    if (e is PostgrestException) throw ServerFailure(e.message);
    if (e is StorageException) throw ServerFailure(e.message);
    throw ServerFailure(e.toString());
  }

  /// Mutations require connectivity; reads may fall back to Hive.
  Future<void> _requireOnline() async {
    if (!await _network.isConnected) throw const NetworkFailure();
  }

  Future<void> _notifyNewItem(WishlistItem item) async {
    await _notifications.show(
      id: item.hashCode & 0x7fffffff,
      title: 'New wishlist item',
      body: '${item.name} was added',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('wishlist', 'Wishlist updates'),
      ),
    );
  }

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
  Future<List<WishlistItem>> getMyItems(String ownerId) async {
    try {
      final items = await _remote.fetchMine(ownerId);
      await _cache.putAll({
        for (final i in items) _scopedKey(ownerId, i.id): i.toJson(),
      });
      return items;
    } catch (e) {
      // Offline → Hive fallback. Online → surface the real failure instead
      // of silently serving stale cache (which hid RLS/schema bugs).
      if (await _network.isConnected) _asFailure(e);
      final cached = await _cache.getAll();
      // Filter by the row's owner_id (not just the key) so a signed-in user
      // never sees another user's cached items.
      return cached
          .where((j) => _belongsTo(j, ownerId))
          .map(WishlistItemModel.fromJson)
          .toList();
    }
  }

  @override
  Future<List<WishlistItem>> getVisibleItems(String ownerId) async {
    final all = await getMyItems(ownerId);
    return all.where((e) => !e.isHidden).toList();
  }

  @override
  Future<WishlistItem?> getItemById(String itemId) =>
      _remote.fetchById(itemId);

  @override
  Future<String> uploadItemImage({
    required String ownerId,
    required String itemId,
    required String filePath,
  }) => _remote.uploadItemImage(
    ownerId: ownerId,
    itemId: itemId,
    filePath: filePath,
  );

  @override
  Future<void> deleteImageByUrl(String imageUrl) =>
      _remote.deleteImageByUrl(imageUrl);

  /// Uploads any device-local image paths, returning public URLs.
  /// [uploaded] collects the new URLs so callers can roll them back if a
  /// later step (e.g. row insert) fails.
  Future<List<String>> _resolveImageUrls(
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

  Future<void> _deleteUrlsBestEffort(Iterable<String> urls) async {
    for (final url in urls) {
      try {
        await deleteImageByUrl(url);
      } catch (_) {
        // Cleanup must never fail the user-facing operation.
      }
    }
  }

  @override
  Future<WishlistItem> addItem(WishlistItem item) async {
    await _requireOnline();
    final uploaded = <String>[];
    try {
      final urls = await _resolveImageUrls(item, uploaded);
      final saved = await _remote.insert(
        WishlistItemModel.fromEntity(item.copyWith(imageUrls: urls)),
      );
      await _cache.put(_scopedKey(saved.ownerId, saved.id), saved.toJson());
      try {
        // Local reminder only: never fail the save over a notification.
        await _notifyNewItem(saved);
      } catch (_) {
        // ignore notification failures
      }
      return saved;
    } catch (e) {
      await _deleteUrlsBestEffort(uploaded);
      _asFailure(e);
    }
  }

  @override
  Future<WishlistItem> updateItem(WishlistItem item) async {
    await _requireOnline();
    final uploaded = <String>[];
    try {
      final urls = await _resolveImageUrls(item, uploaded);
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
          await _deleteUrlsBestEffort(removed);
        }
      } catch (_) {
        // ignore diff cleanup failures
      }
      return saved;
    } catch (e) {
      await _deleteUrlsBestEffort(uploaded);
      _asFailure(e);
    }
  }

  @override
  Future<void> deleteItem(String itemId) async {
    await _requireOnline();
    // NOTE: this deletes only the Supabase row + local cache. Callers must
    // also delete the item's Firestore chats (wired in WishlistBloc via the
    // injected deleteChatsForItem hook) or chats will leak.
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
      _asFailure(e);
    }
    final found = await _findCached(itemId);
    if (found != null) await _cache.delete(found.$1);
    await _deleteUrlsBestEffort(imageUrls);
  }

  @override
  Future<void> setHidden(String itemId, bool hidden) async {
    await _requireOnline();
    final found = await _findCached(itemId);
    if (found != null) {
      await updateItem(found.$2.copyWith(isHidden: hidden));
      return;
    }
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
    await _requireOnline();
    try {
      await _remote.subscribe(subscriberId, targetUserId);
    } catch (e) {
      _asFailure(e);
    }
  }

  @override
  Future<void> unsubscribe(String subscriberId, String targetUserId) async {
    await _requireOnline();
    try {
      await _remote.unsubscribe(subscriberId, targetUserId);
    } catch (e) {
      _asFailure(e);
    }
  }

  @override
  Future<List<Subscription>> mySubscriptions(String subscriberId) async {
    await _requireOnline();
    try {
      return await _remote.fetchSubscriptions(subscriberId);
    } catch (e) {
      _asFailure(e);
    }
  }

  @override
  Stream<List<WishlistItem>> watchUserItems(String ownerId) =>
      _remote.watchMine(ownerId);
}
