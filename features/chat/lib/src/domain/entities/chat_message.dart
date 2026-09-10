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
    required this.ownerId,
    required this.participantIds,
    required this.createdAt,
  });

  final String id;
  final String wishlistItemId;
  final String ownerId;
  final List<String> participantIds;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, wishlistItemId, ownerId, participantIds, createdAt];
}
