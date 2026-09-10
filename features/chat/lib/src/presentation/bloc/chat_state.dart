import 'package:equatable/equatable.dart';

import '../../domain/entities/chat_message.dart';

class ChatState extends Equatable {
  const ChatState({
    this.threads = const [],
    this.messages = const [],
    this.activeChatId,
    this.error,
    this.unreadChatIds = const {},
    this.isLoading = false,
  });

  final List<ChatThread> threads;
  final List<ChatMessage> messages;
  final String? activeChatId;

  /// Transient stream/send failure. Clears on any copy without an explicit
  /// value, matching the other features' error semantics.
  final String? error;

  /// Thread ids with activity the user hasn't opened yet.
  final Set<String> unreadChatIds;

  /// True while the first snapshot of either stream is pending.
  final bool isLoading;

  ChatState copyWith({
    List<ChatThread>? threads,
    List<ChatMessage>? messages,
    String? activeChatId,
    String? error,
    Set<String>? unreadChatIds,
    bool? isLoading,
  }) => ChatState(
    threads: threads ?? this.threads,
    messages: messages ?? this.messages,
    activeChatId: activeChatId ?? this.activeChatId,
    error: error,
    unreadChatIds: unreadChatIds ?? this.unreadChatIds,
    isLoading: isLoading ?? this.isLoading,
  );

  @override
  List<Object?> get props => [
    threads,
    messages,
    activeChatId,
    error,
    unreadChatIds,
    isLoading,
  ];
}
