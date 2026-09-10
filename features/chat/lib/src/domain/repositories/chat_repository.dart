import '../entities/chat_message.dart';

abstract class ChatRepository {
  Stream<List<ChatThread>> watchThreadsForUser(String userId);
  Stream<List<ChatMessage>> watchMessages(String chatId);
  Future<ChatThread> createThread({
    required String wishlistItemId,
    required String ownerId,
    required List<String> participantIds,
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
  /// Destroys all chats (and messages) bound to a wishlist item.
  /// Must be called when the owner deletes the item.
  Future<void> deleteChatsForItem(String wishlistItemId);
  Future<void> deleteThread(String chatId);
}
