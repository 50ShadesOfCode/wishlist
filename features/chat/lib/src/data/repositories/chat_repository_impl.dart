import 'package:core/core.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_photo_storage.dart';
import '../datasources/chat_remote_ds.dart';
import '../models/chat_models.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(
    this._remote, {
    this._photoStorage,
    HiveCacheService? seenCache,
  }) : _seenCache = seenCache ?? HiveCacheService(AppConstants.chatSeenBox);

  final ChatRemoteDataSource _remote;
  final ChatPhotoStorage? _photoStorage;

  /// Local last-opened timestamps per thread (unread badges are derived).
  final HiveCacheService _seenCache;

  /// Maps backend errors to the [Failure] taxonomy so blocs can rely on
  /// `on Failure` instead of formatting raw exceptions.
  Never _asFailure(Object e) {
    if (e is Failure) throw e;
    if (e is FirebaseException) {
      throw ServerFailure(e.message ?? 'Chat operation failed');
    }
    if (e is PostgrestException) throw ServerFailure(e.message);
    if (e is StorageException) throw ServerFailure(e.message);
    throw ServerFailure(e.toString());
  }

  @override
  Stream<List<ChatThread>> watchThreadsForUser(String userId) =>
      _remote.watchThreads(userId);

  @override
  Stream<List<ChatMessage>> watchMessages(String chatId) =>
      _remote.watchMessages(chatId);

  @override
  Future<ChatThread> createThread({
    required String wishlistItemId,
    String wishlistItemName = '',
    required String ownerId,
    required List<String> participantIds,
  }) async {
    try {
      return await _remote.createThread(
        wishlistItemId: wishlistItemId,
        wishlistItemName: wishlistItemName,
        ownerId: ownerId,
        participantIds: participantIds,
      );
    } catch (e) {
      _asFailure(e);
    }
  }

  @override
  Future<ChatThread> getOrCreateThread({
    required String wishlistItemId,
    String wishlistItemName = '',
    required String ownerId,
    required String participantId,
  }) async {
    try {
      final existing = await _remote.findThreadForItem(
        wishlistItemId: wishlistItemId,
        userId: participantId,
      );
      if (existing != null) return existing;
      return await _remote.createThread(
        wishlistItemId: wishlistItemId,
        wishlistItemName: wishlistItemName,
        ownerId: ownerId,
        participantIds: [ownerId, participantId],
      );
    } catch (e) {
      _asFailure(e);
    }
  }

  @override
  Future<ChatMessage> sendText({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    try {
      return await _remote.sendMessage(
        ChatMessageModel(
          id: generateId(),
          chatId: chatId,
          senderId: senderId,
          text: text,
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      _asFailure(e);
    }
  }

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
    try {
      final imageUrl = await storage.upload(
        senderId: senderId,
        chatId: chatId,
        filePath: localImagePath,
      );
      return await _remote.sendMessage(
        ChatMessageModel(
          id: generateId(),
          chatId: chatId,
          senderId: senderId,
          imageUrl: imageUrl,
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      _asFailure(e);
    }
  }

  @override
  Future<Set<String>> unreadThreadIds(
    List<ChatThread> threads,
    String currentUserId,
  ) async {
    final unread = <String>{};
    for (final t in threads) {
      final last = t.lastMessageAt;
      if (last == null || t.lastSenderId == currentUserId) continue;
      DateTime? seen;
      try {
        final raw = await _seenCache.get(t.id);
        final iso = raw?['seen_at'] as String?;
        seen = iso == null ? null : DateTime.tryParse(iso);
      } catch (_) {
        seen = null;
      }
      if (seen == null || last.isAfter(seen)) unread.add(t.id);
    }
    return unread;
  }

  @override
  Future<void> markThreadSeen(String chatId) async {
    try {
      await _seenCache.put(chatId, {
        'seen_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Badge state is best-effort.
    }
  }

  @override
  Future<void> deleteChatsForItem(String wishlistItemId) async {
    try {
      await _remote.deleteChatsForItem(wishlistItemId);
    } catch (e) {
      _asFailure(e);
    }
  }

  @override
  Future<void> deleteThread(String chatId) async {
    try {
      await _remote.deleteThread(chatId);
    } catch (e) {
      _asFailure(e);
    }
  }
}
