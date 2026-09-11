import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';

import '../models/chat_models.dart';

/// Firebase-backed chat data source (secret wishlist discussions).
class ChatRemoteDataSource {
  ChatRemoteDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _threads =>
      _firestore.collection(AppConstants.chatsCollection);

  Stream<List<ChatThreadModel>> watchThreads(String userId) => _threads
      .where('participant_ids', arrayContains: userId)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => ChatThreadModel.fromJson(d.id, d.data()))
            .toList(),
      );

  /// Message history, newest [limit] first-then-reversed to chronological.
  /// Pagination keeps large threads from DOSing the client; pass
  /// [startAfter] (a `created_at` cursor) for older pages.
  static const int messagesPageSize = 100;

  Stream<List<ChatMessageModel>> watchMessages(
    String chatId, {
    int limit = messagesPageSize,
  }) => _threads
      .doc(chatId)
      .collection(AppConstants.messagesCollection)
      .orderBy('created_at', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => ChatMessageModel.fromJson(d.id, d.data()))
            .toList()
            .reversed
            .toList(),
      );

  Future<List<ChatMessageModel>> fetchMessagesPage(
    String chatId, {
    String? startAfterCreatedAt,
    int limit = messagesPageSize,
  }) async {
    var query = _threads
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .orderBy('created_at', descending: true)
        .limit(limit);
    if (startAfterCreatedAt != null) {
      query = query.startAfter([startAfterCreatedAt]);
    }
    final snap = await query.get();
    return snap.docs
        .map((d) => ChatMessageModel.fromJson(d.id, d.data()))
        .toList()
        .reversed
        .toList();
  }

  /// Deterministic thread id for an (item, participant-pair) so two users
  /// tapping Discuss simultaneously converge on one thread instead of
  /// racing find-then-create into duplicates.
  static String threadIdFor({
    required String wishlistItemId,
    required String ownerId,
    required String participantId,
  }) {
    final pair = [ownerId, participantId]..sort();
    return '${wishlistItemId}_${pair.join('_')}'
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }

  Future<ChatThreadModel> createThread({
    required String wishlistItemId,
    String wishlistItemName = '',
    required String ownerId,
    required List<String> participantIds,
  }) async {
    final now = DateTime.now();
    final participants = participantIds.toSet().toList()..sort();
    final docId = threadIdFor(
      wishlistItemId: wishlistItemId,
      ownerId: ownerId,
      participantId: participants.length > 1 ? participants.last : ownerId,
    );
    final ref = _threads.doc(docId);
    await _firestore.runTransaction((tx) async {
      final existing = await tx.get(ref);
      if (!existing.exists) {
        tx.set(ref, {
          'wishlist_item_id': wishlistItemId,
          'wishlist_item_name': wishlistItemName,
          'owner_id': ownerId,
          'participant_ids': participants,
          'created_at': now.toIso8601String(),
        });
      }
    });
    final snap = await ref.get();
    return ChatThreadModel.fromJson(ref.id, snap.data()!);
  }

  Future<ChatMessageModel> sendMessage(ChatMessageModel message) async {
    final doc = await _threads
        .doc(message.chatId)
        .collection(AppConstants.messagesCollection)
        .add(message.toJson());
    final snap = await doc.get();
    // Denormalize for thread-list previews and unread badges.
    try {
      await _threads.doc(message.chatId).update({
        'last_message_at': message.createdAt.toIso8601String(),
        'last_sender_id': message.senderId,
        'last_message_text': message.text ?? '📷',
      });
    } catch (_) {
      // Preview metadata is best-effort; the message itself is saved.
    }
    return ChatMessageModel.fromJson(doc.id, snap.data()!);
  }

  /// Existing thread for [wishlistItemId] visible to [userId], if any.
  /// Server-side `arrayContains` + limit: no unbounded client-side scan.
  Future<ChatThreadModel?> findThreadForItem({
    required String wishlistItemId,
    required String userId,
  }) async {
    final query = await _threads
        .where('wishlist_item_id', isEqualTo: wishlistItemId)
        .where('participant_ids', arrayContains: userId)
        .limit(5)
        .get();
    if (query.docs.isEmpty) return null;
    return ChatThreadModel.fromJson(
      query.docs.first.id,
      query.docs.first.data(),
    );
  }

  /// Deletes threads in bounded pages so large items can't DOS the client.
  static const int threadDeletePageSize = 50;

  Future<void> deleteChatsForItem(String wishlistItemId) async {
    while (true) {
      final query = await _threads
          .where('wishlist_item_id', isEqualTo: wishlistItemId)
          .limit(threadDeletePageSize)
          .get();
      if (query.docs.isEmpty) return;
      for (final doc in query.docs) {
        await _deleteThreadMessages(doc.reference);
        await doc.reference.delete();
      }
    }
  }

  Future<void> deleteThreadsForUser(String userId) async {
    while (true) {
      final query = await _threads
          .where('participant_ids', arrayContains: userId)
          .limit(threadDeletePageSize)
          .get();
      if (query.docs.isEmpty) return;
      for (final doc in query.docs) {
        await _deleteThreadMessages(doc.reference);
        await doc.reference.delete();
      }
    }
  }

  /// Deletes a thread's messages in batches so a mid-loop failure cannot
  /// leave a half-deleted thread behind without surfacing an error.
  Future<void> _deleteThreadMessages(
    DocumentReference<Map<String, dynamic>> thread,
  ) async {
    while (true) {
      final msgs = await thread
          .collection(AppConstants.messagesCollection)
          .limit(400)
          .get();
      if (msgs.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final m in msgs.docs) {
        batch.delete(m.reference);
      }
      await batch.commit();
    }
  }
}
