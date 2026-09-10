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
/// Ops survive restarts and sign-outs. Cross-user leakage is impossible:
/// replay runs against the live backends, so another user's RLS policies
/// reject foreign rows instead of applying them.
class OutboxService extends ChangeNotifier {
  OutboxService(this._cache);

  final HiveCacheService _cache;
  int _pending = 0;

  int get pending => _pending;

  static String opKey(String id) => 'op_$id';

  Future<void> refresh() async {
    try {
      _pending = (await _cache.keys()).length;
    } catch (_) {
      _pending = 0;
    }
    notifyListeners();
  }

  Future<void> enqueue(OutboxKind kind, Map<String, dynamic> payload) async {
    final id = generateId();
    await _cache.put(opKey(id), {
      'key': opKey(id),
      'kind': kind.value,
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
    });
    await refresh();
  }

  /// Pending ops oldest-first. Malformed entries are skipped.
  Future<List<OutboxOperation>> peekOrdered() async {
    final all = await _cache.getAll();
    final rows = [
      for (final m in all)
        if (m['kind'] is String && m['key'] is String) m,
    ];
    rows.sort(
      (a, b) => (a['created_at'] as String? ?? '')
          .compareTo(b['created_at'] as String? ?? ''),
    );
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
}
