import 'package:equatable/equatable.dart';

import '../../domain/entities/chat_message.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object?> get props => [];
}

class ChatThreadWatch extends ChatEvent {
  const ChatThreadWatch(this.userId);
  final String userId;
}

class ChatMessagesWatch extends ChatEvent {
  const ChatMessagesWatch(this.chatId);
  final String chatId;
}

class ChatTextSend extends ChatEvent {
  const ChatTextSend(this.chatId, this.senderId, this.text);
  final String chatId;
  final String senderId;
  final String text;
}

class ChatPhotoSend extends ChatEvent {
  const ChatPhotoSend(this.chatId, this.senderId, this.localImagePath);
  final String chatId;
  final String senderId;
  final String localImagePath;
}

/// Internal: recomputes unread badges after the thread list changes.
class ChatUnreadRefresh extends ChatEvent {
  const ChatUnreadRefresh(this.threads, this.userId);
  final List<ChatThread> threads;
  final String userId;

  @override
  List<Object?> get props => [threads, userId];
}

/// Internal: a new message snapshot arrived (see [_messagesSub] handling).
class ChatMessagesUpdated extends ChatEvent {
  const ChatMessagesUpdated(this.messages);
  final List<ChatMessage> messages;

  @override
  List<Object?> get props => [messages];
}

/// Internal: the message stream failed.
class ChatMessagesFailed extends ChatEvent {
  const ChatMessagesFailed(this.error);
  final String error;

  @override
  List<Object?> get props => [error];
}
