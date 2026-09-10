# chat

Secret wishlist discussions on Firestore (`chats/{id}/messages`), with photo
uploads to the Supabase `avatars` bucket, unread badges, and per-thread
screens. State via `ChatBloc` (use-case driven); creation goes through
`GetOrCreateThreadUseCase`.

Internal package (`publish_to: none`).
