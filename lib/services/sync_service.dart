import 'package:core/core.dart';
import 'package:profile/profile.dart';
import 'package:wishlist/wishlist.dart';

/// Replays the [OutboxService] queue oldest-first once connectivity returns.
///
/// Semantics:
/// - Stops (keeping the rest queued) when connectivity drops mid-drain.
/// - Individual op failures don't block the queue; the failed op stays queued
///   and the drain continues with the rest.
/// - `wishlist_add` is idempotent: if the row already exists (e.g. a crash
///   between insert and dequeue), it becomes an update instead of a
///   duplicate-key failure loop.
class SyncService {
  SyncService(this._outbox, this._wishlist, this._profile, this._network);

  final OutboxService _outbox;
  final WishlistRepository _wishlist;
  final ProfileRepository _profile;
  final NetworkInfo _network;
  bool _syncing = false;

  Future<void> syncNow() async {
    if (_syncing) return;
    if (!await _network.isConnected) return;
    _syncing = true;
    try {
      final ops = await _outbox.peekOrdered();
      for (final op in ops) {
        if (!await _network.isConnected) return;
        final key = op['key'] as String?;
        if (key == null) continue;
        try {
          await _replay(op);
          await _outbox.remove(key);
        } catch (_) {
          // Keep poison ops queued; never let one op starve the rest.
        }
      }
    } finally {
      _syncing = false;
      await _outbox.refresh();
    }
  }

  Future<void> _replay(Map<String, dynamic> op) async {
    final payload = Map<String, dynamic>.from(op['payload'] as Map);
    switch (op['kind']) {
      case 'wishlist_add':
        final item = WishlistItemModel.fromJson(payload);
        final existing = await _wishlist.getItemById(item.id);
        if (existing == null) {
          await _wishlist.addItem(item);
        } else {
          await _wishlist.updateItem(item);
        }
      case 'wishlist_update':
        await _wishlist.updateItem(WishlistItemModel.fromJson(payload));
      case 'wishlist_delete':
        await _wishlist.deleteItem(payload['id'] as String);
      case 'wishlist_subscribe':
        await _wishlist.subscribe(
          payload['subscriber_id'] as String,
          payload['target_user_id'] as String,
        );
      case 'wishlist_unsubscribe':
        await _wishlist.unsubscribe(
          payload['subscriber_id'] as String,
          payload['target_user_id'] as String,
        );
      case 'profile_update':
        await _profile.updateProfile(ProfileModel.fromJson(payload));
      default:
        throw ServerFailure('Unknown outbox op: ${op['kind']}');
    }
  }
}
