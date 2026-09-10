import 'package:core/core.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_photo_storage.dart';
import '../datasources/chat_remote_ds.dart';
import '../models/chat_models.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._remote, {this._photoStorage});

  final ChatRemoteDataSource _remote;
  final ChatPhotoStorage? _photoStorage;

  @override
  Stream<List<ChatThread>> watchThreadsForUser(String userId) =>
      _remote.watchThreads(userId);

  @override
  Stream<List<ChatMessage>> watchMessages(String chatId) =>
      _remote.watchMessages(chatId);

  @override
  Future<ChatThread> createThread({
    required String wishlistItemId,
    required String ownerId,
    required List<String> participantIds,
  }) => _remote.createThread(
    wishlistItemId: wishlistItemId,
    ownerId: ownerId,
    participantIds: participantIds,
  );

  @override
  Future<ChatMessage> sendText({
    required String chatId,
    required String senderId,
    required String text,
  }) => _remote.sendMessage(
    ChatMessageModel(
      id: generateId(),
      chatId: chatId,
      senderId: senderId,
      text: text,
      createdAt: DateTime.now(),
    ),
  );

  @override
  Future<ChatMessage> sendPhoto({
    required String chatId,
    required String senderId,
    required String localImagePath,
  }) async {
    final storage = _photoStorage;
    if (storage == null) {
      throw const ServerException('Photo upload is not configured');
    }
    // Upload first so the persisted message carries a public URL readable
    // by all participants — never a sender-local device path.
    final imageUrl = await storage.upload(
      senderId: senderId,
      chatId: chatId,
      filePath: localImagePath,
    );
    return _remote.sendMessage(
      ChatMessageModel(
        id: generateId(),
        chatId: chatId,
        senderId: senderId,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> deleteChatsForItem(String wishlistItemId) =>
      _remote.deleteChatsForItem(wishlistItemId);

  @override
  Future<void> deleteThread(String chatId) => _remote.deleteThread(chatId);
}
