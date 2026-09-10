/// Safe display label for a thread's wishlist item id. Never throws on
/// short or empty ids (the previous `substring(0, 6)` crashed with a
/// RangeError on any id shorter than 6 characters).
String threadLabel(String wishlistItemId) {
  if (wishlistItemId.isEmpty) return 'Wish…';
  final short = wishlistItemId.length <= 6
      ? wishlistItemId
      : wishlistItemId.substring(0, 6);
  return 'Wish $short…';
}
