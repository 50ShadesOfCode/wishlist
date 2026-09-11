import 'package:flutter/foundation.dart';

import '../utils/id_generator.dart';
import 'hive_service.dart';
import 'outbox_kind.dart';
import 'outbox_operation.dart';

/// Durable FIFO queue of mutations made while offline.
///
/// Repositories enqueue instead of throwing [NetworkFailure] when there is no
/// connectivity (writes land in Hive immediately so the UI stays usable);
/// [SyncService] (app layer) replays the queue in order once back online.
///
/// Ops are user-scoped ([OutboxOperation.userId]): after an account switch,
/// foreign ops are purged on sign-in instead of replaying as the new user
/// (RLS would reject them, but replaying them wastes bandwidth and leaves
/// poison ops queued forever).
class OutboxService extends ChangeNotifier {
  OutboxService(this._cache);

  final HiveCacheService _cache;
  int _pending = 0;

  int get pending => _pending;

  /// Replay failures after which an op is dead-lettered (dropped with a log).
  static const int maxRetries = 5;

  /// Set by [SyncService] during a drain: [enqueueOfflineWrite] then forces
  /// remote-only (throws instead of re-enqueueing) so a connectivity flap
  /// mid-drain can't loop ops back into the queue.
  static bool replayMode = false;

  static String opKey(String id) => 'op_$id';

  Future<void> refresh() async {
    try {
      _pending = (await _cache.keys()).length;
    } catch (_) {
      _pending = 0;
    }
    notifyListeners();
  }

  Future<int> _nextSeqno() async {
    var max = 0;
    for (final m in await _cache.getAll()) {
      final s = (m['seqno'] as num?)?.toInt() ?? 0;
      if (s > max) max = s;
    }
    return max + 1;
  }

  /// Enqueues an op, coalescing wasteful sequences first:
  /// - `add -> delete` for the same item: drops the pending add, skips the
  ///   delete (nothing ever reached the server).
  /// - `add -> update` for the same item: folds the update into the pending
  ///   add payload.
  /// - `update -> update` for the same item: replaces the pending payload.
  /// - `subscribe -> unsubscribe` (or reverse) for the same pair: both
  ///   cancel out (or the earlier op is dropped).
  /// Returns true when the op was absorbed (caller must not enqueue).
  Future<void> enqueue(
    OutboxKind kind,
    Map<String, dynamic> payload, {
    String? userId,
  }) async {
    if (await _coalesce(kind, payload)) {
      await refresh();
      return;
    }
    final id = generateId();
    final entry = <String, dynamic>{
      'key': opKey(id),
      'kind': kind.value,
      'payload': payload,
      'seqno': await _nextSeqno(),
      'retry_count': 0,
      'created_at': DateTime.now().toIso8601String(),
    };
    if (userId != null) entry['user_id'] = userId;
    await _cache.put(opKey(id), entry);
    await refresh();
  }

  /// Pending ops in replay order (monotonic seqno, `created_at` tiebreak).
  /// Malformed entries are skipped.
  Future<List<OutboxOperation>> peekOrdered() async {
    final all = await _cache.getAll();
    final rows = [
      for (final m in all)
        if (m['kind'] is String && m['key'] is String) m,
    ];
    rows.sort((a, b) {
      final seq = ((a['seqno'] as num?)?.toInt() ?? 0).compareTo(
        ((b['seqno'] as num?)?.toInt() ?? 0),
      );
      if (seq != 0) return seq;
      return (a['created_at'] as String? ?? '').compareTo(
        b['created_at'] as String? ?? '',
      );
    });
    final ops = <OutboxOperation>[];
    for (final row in rows) {
      try {
        ops.add(OutboxOperation.fromJson(row));
      } catch (_) {
        // Skip entries whose payload is not a map.
      }
    }
    return ops;
  }

  Future<void> remove(String key) async {
    await _cache.delete(key);
    await refresh();
  }

  /// Dead-letter eviction sweep: drops ops that already exhausted
  /// [maxRetries] (e.g. written by an older build before counting existed
  /// but since fixed server-side). Returns the evicted count.
  Future<int> evictDeadLetters() async {
    var evicted = 0;
    for (final op in await peekOrdered()) {
      if (op.retryCount >= maxRetries) {
        await _cache.delete(op.key);
        evicted++;
      }
    }
    if (evicted > 0) await refresh();
    return evicted;
  }

  /// Releases the held Hive handle (called on app dispose).
  @override
  void dispose() {
    _cache.close();
    super.dispose();
  }

  /// Records one replay failure; dead-letters (drops with a log line) after
  /// [maxRetries] so a single poison op can't clog the queue forever.
  /// Returns true when the op was dead-lettered.
  Future<bool> noteFailure(OutboxOperation op) async {
    final next = op.retryCount + 1;
    if (next >= maxRetries) {
      await _cache.delete(op.key);
      await refresh();
      return true;
    }
    final current = await _cache.get(op.key);
    if (current != null) {
      await _cache.put(op.key, {...current, 'retry_count': next});
    }
    await refresh();
    return false;
  }

  /// Drops ops owned by anyone other than [userId] (called on sign-in).
  /// Ops without a userId (pre-scoping entries) are kept.
  Future<int> purgeForeignOps(String userId) async {
    var dropped = 0;
    for (final op in await peekOrdered()) {
      if (op.userId != null && op.userId != userId) {
        await _cache.delete(op.key);
        dropped++;
      }
    }
    if (dropped > 0) await refresh();
    return dropped;
  }

  // -- coalescing ----------------------------------------------------------

  String? _itemId(OutboxKind kind, Map<String, dynamic> payload) {
    switch (kind) {
      case OutboxKind.wishlistAdd:
      case OutboxKind.wishlistUpdate:
        final id = payload['id'];
        return id is String && id.isNotEmpty ? id : null;
      case OutboxKind.wishlistDelete:
        final id = payload['id'];
        return id is String && id.isNotEmpty ? id : null;
      default:
        return null;
    }
  }

  (String, String)? _subPair(Map<String, dynamic> payload) {
    final s = payload['subscriber_id'];
    final t = payload['target_user_id'];
    if (s is! String || s.isEmpty || t is! String || t.isEmpty) return null;
    return (s, t);
  }

  Future<bool> _coalesce(
    OutboxKind kind,
    Map<String, dynamic> payload,
  ) async {
    final ops = await peekOrdered();
    if (ops.isEmpty) return false;
    if (kind == OutboxKind.wishlistDelete) {
      final id = _itemId(kind, payload);
      if (id == null) return false;
      // add -> delete: the row never reached the server; drop the add.
      for (final op in ops) {
        if (op.kind == OutboxKind.wishlistAdd.value &&
            _itemId(OutboxKind.wishlistAdd, op.payload) == id) {
          await _cache.delete(op.key);
          return true;
        }
      }
      // update -> delete: pending updates are moot; drop them, keep delete.
      for (final op in ops) {
        if (op.kind == OutboxKind.wishlistUpdate.value &&
            _itemId(OutboxKind.wishlistUpdate, op.payload) == id) {
          await _cache.delete(op.key);
        }
      }
      return false;
    }
    if (kind == OutboxKind.wishlistUpdate) {
      final id = _itemId(kind, payload);
      if (id == null) return false;
      for (final op in ops.reversed) {
        // Fold into the newest pending add/update for the same item.
        if ((op.kind == OutboxKind.wishlistAdd.value ||
                op.kind == OutboxKind.wishlistUpdate.value) &&
            _itemId(OutboxKind.wishlistAdd, op.payload) == id) {
          await _cache.put(op.key, {...op.toJson(), 'payload': payload});
          return true;
        }
      }
      return false;
    }
    if (kind == OutboxKind.wishlistSubscribe ||
        kind == OutboxKind.wishlistUnsubscribe) {
      final pair = _subPair(payload);
      if (pair == null) return false;
      final opposite = kind == OutboxKind.wishlistSubscribe
          ? OutboxKind.wishlistUnsubscribe.value
          : OutboxKind.wishlistSubscribe.value;
      for (final op in ops) {
        if (op.kind == opposite && _subPair(op.payload) == pair) {
          await _cache.delete(op.key);
          return true;
        }
      }
      return false;
    }
    return false;
  }
}
