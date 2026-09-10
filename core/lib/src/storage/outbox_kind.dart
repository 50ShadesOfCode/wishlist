/// Closed set of offline op types.
///
/// Repositories enqueue with these values; replay use-cases and [SyncService]
/// switch on them. Single source of truth — no kind string literals anywhere
/// else in the codebase.
enum OutboxKind {
  wishlistAdd('wishlist_add', OutboxScope.wishlist),
  wishlistUpdate('wishlist_update', OutboxScope.wishlist),
  wishlistDelete('wishlist_delete', OutboxScope.wishlist),
  wishlistSubscribe('wishlist_subscribe', OutboxScope.wishlist),
  wishlistUnsubscribe('wishlist_unsubscribe', OutboxScope.wishlist),
  profileUpdate('profile_update', OutboxScope.profile);

  const OutboxKind(this.value, this.scope);

  /// Stable on-disk string stored in the outbox entry.
  final String value;

  /// Owning feature, used to route ops to the right replay use-case.
  final OutboxScope scope;

  static OutboxKind? fromValue(String value) {
    for (final kind in OutboxKind.values) {
      if (kind.value == value) return kind;
    }
    return null;
  }
}

/// Feature area owning an outbox op. Add a value here before introducing a
/// new feature's offline queue.
enum OutboxScope { wishlist, profile }
