# wishlist

Wishlist CRUD (Supabase `wishlist_items`), subscriptions, following feed, map
places, item photo uploads, and offline outbox queueing. State via
`WishlistBloc` (use-case driven); item deletion also destroys Firestore chats
through the `DeleteItemUseCase` hook wired in app DI.

Internal package (`publish_to: none`).
