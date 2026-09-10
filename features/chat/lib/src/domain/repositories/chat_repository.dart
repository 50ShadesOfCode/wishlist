import '../entities/chat_message.dart';

abstract class ChatRepository {
  Stream<List<ChatThread>> watchThreadsForUser(String userId);
  Stream<List<ChatMessage>> watchMessages(String chatId);
  Future<ChatThread> createThread({
    required String wishlistItemId,
    String wishlistItemName,
    required String ownerId,
    required List<String> participantIds,
  });

  /// Existing thread for the item visible to [participantId], or a new one
  /// with participants `[ownerId, participantId]` when none exists.
  Future<ChatThread> getOrCreateThread({
    required String wishlistItemId,
    String wishlistItemName,
    required String ownerId,
    required String participantId,
  });
  Future<ChatMessage> sendText({
    required String chatId,
    required String senderId,
    required String text,
  });
  Future<ChatMessage> sendPhoto({
    required String chatId,
    required String senderId,
    required String localImagePath,
  });

  /// Ids of [threads] with activity newer than the local last-seen mark and
  /// not sent by [currentUserId].
  Future<Set<String>> unreadThreadIds(
    List<ChatThread> threads,
    String currentUserId,
  );

  /// Records opening a thread (clears its unread badge).
  Future<void> markThreadSeen(String chatId);

  /// Destroys all chats (and messages) bound to a wishlist item.
  /// Must be called when the owner deletes the item.
  Future<void> deleteChatsForItem(String wishlistItemId);
  Future<void> deleteThread(String chatId);
}
