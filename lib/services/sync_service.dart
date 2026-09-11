import 'package:core/core.dart';

/// Replays the [OutboxService] queue oldest-first once connectivity returns.
///
/// Depends only on replay use-cases (never repositories or data models):
/// payload parsing lives in the owning feature. Ops are routed through the
/// [_replays] registry keyed by [OutboxScope]; unknown kinds are poison ops
/// left queued with a log.
///
/// Semantics:
/// - Stops (keeping the rest queued) when connectivity drops mid-drain.
/// - Individual op failures don't block the queue; the failed op stays queued
///   and the drain continues with the rest.
class SyncService {
  SyncService(this._outbox, this._replays, this._network);

  final OutboxService _outbox;

  /// Replay entry point per feature area. New offline-capable features
  /// register here instead of adding branches to [_replay].
  final Map<OutboxScope, UseCase<void, OutboxOperation>> _replays;

  final NetworkInfo _network;
  bool _syncing = false;

  /// Firebase uid of the current user. Ops owned by anyone else are skipped
  /// (purged at sign-in; this is a second line of defense).
  String? currentUserId;

  Future<void> syncNow() async {
    if (_syncing) return;
    if (!await _network.isConnected) return;
    _syncing = true;
    OutboxService.replayMode = true;
    var replayed = 0;
    var skipped = 0;
    var deadLettered = 0;
    try {
      final ops = await _outbox.peekOrdered();
      appLogger.info('Sync started (${ops.length} queued ops)');
      for (final op in ops) {
        if (!await _network.isConnected) return;
        if (currentUserId != null &&
            op.userId != null &&
            op.userId != currentUserId) {
          await _outbox.remove(op.key);
          skipped++;
          appLogger.warning(
            'Sync dropped foreign op ${op.kind} (${op.key})',
          );
          continue;
        }
        try {
          await _replay(op);
          await _outbox.remove(op.key);
          replayed++;
        } catch (e) {
          // Failed ops stay queued with a persisted retry count and the
          // drain continues; poison ops are dead-lettered after N retries.
          final dropped = await _outbox.noteFailure(op);
          if (dropped) {
            deadLettered++;
            appLogger.warning(
              'Sync dead-lettered ${op.kind} op (${op.key}): $e',
            );
          } else {
            skipped++;
            appLogger.warning('Sync skipped ${op.kind} op (${op.key}): $e');
          }
        }
      }
      appLogger.info(
        'Sync finished (replayed: $replayed, skipped: $skipped, '
        'dead-lettered: $deadLettered)',
      );
    } finally {
      OutboxService.replayMode = false;
      _syncing = false;
      await _outbox.refresh();
    }
  }

  Future<void> _replay(OutboxOperation op) {
    final kind = OutboxKind.fromValue(op.kind);
    final replay = kind == null ? null : _replays[kind.scope];
    if (replay == null) throw ServerFailure('Unknown outbox op: ${op.kind}');
    return replay(op);
  }
}
