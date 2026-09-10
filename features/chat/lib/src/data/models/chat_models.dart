import '../../domain/entities/chat_message.dart';

class ChatMessageModel extends ChatMessage {
  const ChatMessageModel({
    required super.id,
    required super.chatId,
    required super.senderId,
    super.text,
    super.imageUrl,
    required super.createdAt,
  });

  factory ChatMessageModel.fromJson(String id, Map<String, dynamic> json) =>
      ChatMessageModel(
        id: id,
        chatId: json['chat_id'] as String,
        senderId: json['sender_id'] as String,
        text: json['text'] as String?,
        imageUrl: json['image_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
    'chat_id': chatId,
    'sender_id': senderId,
    'text': text,
    'image_url': imageUrl,
    'created_at': createdAt.toIso8601String(),
  };
}

class ChatThreadModel extends ChatThread {
  const ChatThreadModel({
    required super.id,
    required super.wishlistItemId,
    required super.ownerId,
    required super.participantIds,
    required super.createdAt,
  });

  factory ChatThreadModel.fromJson(String id, Map<String, dynamic> json) =>
      ChatThreadModel(
        id: id,
        wishlistItemId: json['wishlist_item_id'] as String,
        ownerId: json['owner_id'] as String,
        participantIds:
            (json['participant_ids'] as List?)?.cast<String>() ?? const [],
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
    'wishlist_item_id': wishlistItemId,
    'owner_id': ownerId,
    'participant_ids': participantIds,
    'created_at': createdAt.toIso8601String(),
  };
}
