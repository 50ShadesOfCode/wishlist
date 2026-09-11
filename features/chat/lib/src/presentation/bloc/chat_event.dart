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

/// Internal: a new thread-list snapshot arrived (fed by the bloc's thread
/// subscription).
class ChatThreadsUpdated extends ChatEvent {
  const ChatThreadsUpdated(this.threads, this.userId);
  final List<ChatThread> threads;
  final String userId;

  @override
  List<Object?> get props => [threads, userId];
}

/// Internal: the thread-list stream failed.
class ChatThreadsFailed extends ChatEvent {
  const ChatThreadsFailed(this.error);
  final String error;

  @override
  List<Object?> get props => [error];
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

/// Internal: a new message snapshot arrived (fed by the bloc's message
/// subscription).
/// Carries [chatId] so late snapshots from a previously-open thread are
/// ignored once the user has switched threads (stale-thread guard).
class ChatMessagesUpdated extends ChatEvent {
  const ChatMessagesUpdated(this.chatId, this.messages);
  final String chatId;
  final List<ChatMessage> messages;

  @override
  List<Object?> get props => [chatId, messages];
}

/// Internal: the message stream failed. Carries [chatId] for the same
/// stale-thread guard as [ChatMessagesUpdated].
class ChatMessagesFailed extends ChatEvent {
  const ChatMessagesFailed(this.chatId, this.error);
  final String chatId;
  final String error;

  @override
  List<Object?> get props => [chatId, error];
}

/// Clears the open thread (messages + [ChatState.activeChatId]). Dispatched
/// when leaving the thread view so a later watch starts from a clean slate.
class ChatThreadClosed extends ChatEvent {
  const ChatThreadClosed();
}

/// Resets the bloc to its initial state. Dispatched on sign-out so the next
/// user never sees the previous user's threads/messages.
class ChatReset extends ChatEvent {
  const ChatReset();
}
