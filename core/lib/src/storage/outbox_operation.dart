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
  });

  /// Hive key of the queued entry (for removal after replay).
  final String key;

  /// Op type, e.g. `wishlist_add`, `profile_update`.
  final String kind;

  /// Opaque op data; interpreted by the owning feature's replay use-case.
  final Map<String, dynamic> payload;

  factory OutboxOperation.fromJson(Map<String, dynamic> json) =>
      OutboxOperation(
        key: json['key'] as String,
        kind: json['kind'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
      );
}
