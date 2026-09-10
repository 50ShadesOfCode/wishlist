import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.text,
    this.imageUrl,
    required this.createdAt,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String? text;
  final String? imageUrl;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, chatId, senderId, text, imageUrl, createdAt];
}

class ChatThread extends Equatable {
  const ChatThread({
    required this.id,
    required this.wishlistItemId,
    this.wishlistItemName = '',
    required this.ownerId,
    required this.participantIds,
    required this.createdAt,
    this.lastMessageAt,
    this.lastSenderId,
    this.lastMessageText,
  });

  final String id;
  final String wishlistItemId;

  /// Wish name snapshot taken at thread creation (for list display without
  /// joining the wishlist feature). Empty for threads created before it.
  final String wishlistItemName;
  final String ownerId;
  final List<String> participantIds;
  final DateTime createdAt;

  /// Denormalized latest-message metadata for unread badges.
  final DateTime? lastMessageAt;
  final String? lastSenderId;
  final String? lastMessageText;

  @override
  List<Object?> get props => [
    id,
    wishlistItemId,
    wishlistItemName,
    ownerId,
    participantIds,
    createdAt,
    lastMessageAt,
    lastSenderId,
    lastMessageText,
  ];
}
