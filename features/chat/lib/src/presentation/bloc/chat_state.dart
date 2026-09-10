import 'package:equatable/equatable.dart';

import '../../domain/entities/chat_message.dart';

class ChatState extends Equatable {
  const ChatState({
    this.threads = const [],
    this.messages = const [],
    this.activeChatId,
    this.error,
  });

  final List<ChatThread> threads;
  final List<ChatMessage> messages;
  final String? activeChatId;

  /// Transient stream/send failure. Clears on any copy without an explicit
  /// value, matching the other features' error semantics.
  final String? error;

  ChatState copyWith({
    List<ChatThread>? threads,
    List<ChatMessage>? messages,
    String? activeChatId,
    String? error,
  }) => ChatState(
    threads: threads ?? this.threads,
    messages: messages ?? this.messages,
    activeChatId: activeChatId ?? this.activeChatId,
    error: error,
  );

  @override
  List<Object?> get props => [threads, messages, activeChatId, error];
}
