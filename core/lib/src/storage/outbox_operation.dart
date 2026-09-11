/// A single queued offline mutation.
///
/// Produced by repositories (via [OutboxService.enqueue]), consumed by
/// feature-level replay use-cases. Keeping the shape in core lets the app
/// layer route ops without importing feature data models.
class OutboxOperation {
  const OutboxOperation({
    required this.key,
    required this.kind,
    required this.payload,
    this.seqno = 0,
    this.retryCount = 0,
    this.userId,
  });

  /// Hive key of the queued entry (for removal after replay).
  final String key;

  /// Op type, e.g. `wishlist_add`, `profile_update`.
  final String kind;

  /// Opaque op data; interpreted by the owning feature's replay use-case.
  final Map<String, dynamic> payload;

  /// Monotonic sequence number: replay order. Older entries without a seqno
  /// sort first (seqno 0) with `created_at` as tiebreak.
  final int seqno;

  /// Persisted replay failures. [SyncService] dead-letters the op after
  /// [OutboxService.maxRetries].
  final int retryCount;

  /// Owning Firebase uid. Ops from another user are never replayed as the
  /// current user — they are skipped/purged on sign-in.
  final String? userId;

  factory OutboxOperation.fromJson(Map<String, dynamic> json) =>
      OutboxOperation(
        key: json['key'] as String,
        kind: json['kind'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        seqno: (json['seqno'] as num?)?.toInt() ?? 0,
        retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
        userId: json['user_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'key': key,
    'kind': kind,
    'payload': payload,
    'seqno': seqno,
    'retry_count': retryCount,
    if (userId != null) 'user_id': userId,
  };
}
