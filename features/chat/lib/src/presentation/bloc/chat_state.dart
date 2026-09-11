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

  static const _activeChatIdSentinel = Object();

  ChatState copyWith({
    List<ChatThread>? threads,
    List<ChatMessage>? messages,
    Object? activeChatId = _activeChatIdSentinel,
    String? error,
    Set<String>? unreadChatIds,
    bool? isLoading,
    bool clearActiveChat = false,
  }) => ChatState(
    threads: threads ?? this.threads,
    messages: messages ?? this.messages,
    // `activeChatId: null` explicitly clears (same sentinel pattern as
    // AuthState.user); `clearActiveChat: true` forces the clear without
    // passing null. Omitted preserves.
    activeChatId: clearActiveChat
        ? null
        : identical(activeChatId, _activeChatIdSentinel)
        ? this.activeChatId
        : activeChatId as String?,
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
