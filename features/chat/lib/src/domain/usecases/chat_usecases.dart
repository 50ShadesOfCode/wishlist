import 'package:core/core.dart';

import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

class WatchThreadsUseCase implements StreamUseCase<List<ChatThread>, String> {
  WatchThreadsUseCase(this._repo);
  final ChatRepository _repo;

  @override
  Stream<List<ChatThread>> call(String userId) =>
      _repo.watchThreadsForUser(userId);
}

class WatchMessagesUseCase implements StreamUseCase<List<ChatMessage>, String> {
  WatchMessagesUseCase(this._repo);
  final ChatRepository _repo;

  @override
  Stream<List<ChatMessage>> call(String chatId) =>
      _repo.watchMessages(chatId);
}

class SendTextParams {
  const SendTextParams({
    required this.chatId,
    required this.senderId,
    required this.text,
  });
  final String chatId;
  final String senderId;
  final String text;
}

class SendTextMessageUseCase implements UseCase<ChatMessage, SendTextParams> {
  SendTextMessageUseCase(this._repo);
  final ChatRepository _repo;

  @override
  Future<ChatMessage> call(SendTextParams params) => _repo.sendText(
    chatId: params.chatId,
    senderId: params.senderId,
    text: params.text,
  );
}

class SendPhotoParams {
  const SendPhotoParams({
    required this.chatId,
    required this.senderId,
    required this.localImagePath,
  });
  final String chatId;
  final String senderId;
  final String localImagePath;
}

class SendPhotoMessageUseCase implements UseCase<ChatMessage, SendPhotoParams> {
  SendPhotoMessageUseCase(this._repo);
  final ChatRepository _repo;

  @override
  Future<ChatMessage> call(SendPhotoParams params) => _repo.sendPhoto(
    chatId: params.chatId,
    senderId: params.senderId,
    localImagePath: params.localImagePath,
  );
}

class GetUnreadThreadsParams {
  const GetUnreadThreadsParams({
    required this.threads,
    required this.currentUserId,
  });
  final List<ChatThread> threads;
  final String currentUserId;
}

class GetUnreadThreadsUseCase
    implements UseCase<Set<String>, GetUnreadThreadsParams> {
  GetUnreadThreadsUseCase(this._repo);
  final ChatRepository _repo;

  @override
  Future<Set<String>> call(GetUnreadThreadsParams params) =>
      _repo.unreadThreadIds(params.threads, params.currentUserId);
}

class MarkThreadSeenUseCase implements UseCase<void, String> {
  MarkThreadSeenUseCase(this._repo);
  final ChatRepository _repo;

  @override
  Future<void> call(String chatId) => _repo.markThreadSeen(chatId);
}

class GetOrCreateThreadParams {
  const GetOrCreateThreadParams({
    required this.wishlistItemId,
    this.wishlistItemName = '',
    required this.ownerId,
    required this.participantId,
  });
  final String wishlistItemId;
  final String wishlistItemName;
  final String ownerId;
  final String participantId;
}

class GetOrCreateThreadUseCase
    implements UseCase<ChatThread, GetOrCreateThreadParams> {
  GetOrCreateThreadUseCase(this._repo);
  final ChatRepository _repo;

  @override
  Future<ChatThread> call(GetOrCreateThreadParams params) =>
      _repo.getOrCreateThread(
        wishlistItemId: params.wishlistItemId,
        wishlistItemName: params.wishlistItemName,
        ownerId: params.ownerId,
        participantId: params.participantId,
      );
}
