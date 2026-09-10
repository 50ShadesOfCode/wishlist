import 'package:core/core.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_photo_storage.dart';
import '../datasources/chat_remote_ds.dart';
import '../models/chat_models.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(
    this._remote, {
    required this._photoStorage,
    required this._network,
    HiveCacheService? seenCache,
  }) : _seenCache = seenCache ?? HiveCacheService(AppConstants.chatSeenBox);

  final ChatRemoteDataSource _remote;
  final ChatPhotoStorage _photoStorage;

  /// Offline contract, unified with wishlist/profile: mutations throw
  /// [NetworkFailure] when offline instead of leaking raw backend errors.
  /// (Watch streams are exempt — Firestore serves those from local cache.)
  final NetworkInfo _network;

  /// Throws [NetworkFailure] when offline. Call first in every mutating op.
  Future<void> _requireOnline() async {
    if (!await _network.isConnected) throw const NetworkFailure();
  }

  /// Local last-opened timestamps per thread (unread badges are derived).
  final HiveCacheService _seenCache;

  @override
  Stream<List<ChatThread>> watchThreadsForUser(String userId) =>
      _remote.watchThreads(userId);

  @override
  Stream<List<ChatMessage>> watchMessages(String chatId) =>
      _remote.watchMessages(chatId);

  @override
  Future<ChatThread> getOrCreateThread({
    required String wishlistItemId,
    String wishlistItemName = '',
    required String ownerId,
    required String participantId,
  }) async {
    await _requireOnline();
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
      mapDataError(e);
    }
  }

  @override
  Future<ChatMessage> sendText({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    await _requireOnline();
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
      mapDataError(e);
    }
  }

  @override
  Future<ChatMessage> sendPhoto({
    required String chatId,
    required String senderId,
    required String localImagePath,
  }) async {
    await _requireOnline();
    // Upload first so the persisted message carries a public URL readable
    // by all participants — never a sender-local device path.
    try {
      final imageUrl = await _photoStorage.upload(
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
      mapDataError(e);
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
    await _requireOnline();
    try {
      await _remote.deleteChatsForItem(wishlistItemId);
    } catch (e) {
      mapDataError(e);
    }
  }
}
