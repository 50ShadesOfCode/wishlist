import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';

import '../models/chat_models.dart';

/// Firebase-backed chat data source (secret wishlist discussions).
class ChatRemoteDataSource {
  ChatRemoteDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _threads =>
      _firestore.collection(AppConstants.chatsCollection);

  Stream<List<ChatThreadModel>> watchThreads(String userId) =>
      _threads.where('participant_ids', arrayContains: userId).snapshots().map(
        (s) => s.docs.map((d) => ChatThreadModel.fromJson(d.id, d.data())).toList(),
      );

  Stream<List<ChatMessageModel>> watchMessages(String chatId) => _threads
      .doc(chatId)
      .collection(AppConstants.messagesCollection)
      .orderBy('created_at')
      .snapshots()
      .map(
        (s) => s.docs.map((d) => ChatMessageModel.fromJson(d.id, d.data())).toList(),
      );

  Future<ChatThreadModel> createThread({
    required String wishlistItemId,
    required String ownerId,
    required List<String> participantIds,
  }) async {
    final now = DateTime.now();
    final doc = await _threads.add({
      'wishlist_item_id': wishlistItemId,
      'owner_id': ownerId,
      'participant_ids': participantIds,
      'created_at': now.toIso8601String(),
    });
    final snap = await doc.get();
    return ChatThreadModel.fromJson(doc.id, snap.data()!);
  }

  Future<ChatMessageModel> sendMessage(ChatMessageModel message) async {
    final doc = await _threads
        .doc(message.chatId)
        .collection(AppConstants.messagesCollection)
        .add(message.toJson());
    final snap = await doc.get();
    return ChatMessageModel.fromJson(doc.id, snap.data()!);
  }

  Future<void> deleteChatsForItem(String wishlistItemId) async {
    final query = await _threads
        .where('wishlist_item_id', isEqualTo: wishlistItemId)
        .get();
    for (final doc in query.docs) {
      await _deleteThreadMessages(doc.reference);
      await doc.reference.delete();
    }
  }

  Future<void> deleteThread(String chatId) async {
    final thread = _threads.doc(chatId);
    await _deleteThreadMessages(thread);
    await thread.delete();
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
