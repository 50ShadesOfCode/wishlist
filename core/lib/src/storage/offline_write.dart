import '../error/map_failure.dart';
import '../network/network_info.dart';
import 'outbox_kind.dart';
import 'outbox_service.dart';

/// Runs [remote], falling back to [fallback] (usually Hive) when offline.
/// Online failures are mapped via [mapDataError] instead of silently serving
/// stale cache.
Future<T> cachedRead<T>({
  required NetworkInfo network,
  required Future<T> Function() remote,
  required Future<T> Function() fallback,
}) async {
  try {
    return await remote();
  } catch (e) {
    if (await network.isConnected) mapDataError(e);
    return fallback();
  }
}

/// Queues an offline write. Returns true when the caller should return its
/// cached value instead of hitting the network; false when online (caller
/// proceeds with the remote call).
Future<bool> enqueueOfflineWrite({
  required NetworkInfo network,
  required OutboxService outbox,
  required OutboxKind kind,
  required Map<String, dynamic> payload,
  required Future<void> Function() writeCache,
}) async {
  if (await network.isConnected) return false;
  await writeCache();
  await outbox.enqueue(kind, payload);
  return true;
}
