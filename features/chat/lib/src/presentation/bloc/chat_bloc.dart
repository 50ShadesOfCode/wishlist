import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/usecases/chat_usecases.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({
    required this._watchThreads,
    required this._watchMessages,
    required this._sendTextMessage,
    required this._sendPhotoMessage,
    required this._getUnreadThreads,
    required this._markThreadSeen,
    this._onNewMessage,
  }) : super(const ChatState()) {
    on<ChatThreadWatch>(_onThreads);
    on<ChatThreadsUpdated>(_onThreadsUpdated);
    on<ChatThreadsFailed>(_onThreadsFailed);
    on<ChatMessagesWatch>(_onMessages);
    on<ChatMessagesUpdated>(_onMessagesUpdated);
    on<ChatMessagesFailed>(_onMessagesFailed);
    on<ChatThreadClosed>(_onThreadClosed);
    on<ChatReset>(_onReset);
    on<ChatTextSend>(_onSendText);
    on<ChatPhotoSend>(_onSendPhoto);
    on<ChatUnreadRefresh>(_onUnreadRefresh);
  }

  final WatchThreadsUseCase _watchThreads;
  final WatchMessagesUseCase _watchMessages;
  final SendTextMessageUseCase _sendTextMessage;
  final SendPhotoMessageUseCase _sendPhotoMessage;
  final GetUnreadThreadsUseCase _getUnreadThreads;
  final MarkThreadSeenUseCase _markThreadSeen;

  /// Fired once per newly-unread thread (wired to local notifications).
  /// Skipped for the currently open thread.
  final Future<void> Function(ChatThread thread)? _onNewMessage;

  /// Active thread-list subscription. Replaced (with cancel) on every
  /// [ChatThreadWatch] so re-watches never stack overlapping streams.
  /// A manual subscription (not `emit.forEach`) because the stream is
  /// infinite: awaiting `forEach` under the default sequential transformer
  /// would block the event queue and starve message/sends events.
  StreamSubscription<List<ChatThread>>? _threadsSub;

  /// Active message subscription. Replaced (with cancel) on every
  /// [ChatMessagesWatch] so rapid thread switches never leave overlapping
  /// streams writing into each other's state.
  StreamSubscription<List<ChatMessage>>? _messagesSub;

  @override
  Future<void> close() {
    _threadsSub?.cancel();
    _messagesSub?.cancel();
    return super.close();
  }

  Future<void> _onThreads(ChatThreadWatch e, Emitter<ChatState> emit) async {
    await _threadsSub?.cancel();
    emit(state.copyWith(isLoading: true));
    _threadsSub = _watchThreads(e.userId).listen(
      (threads) => add(ChatThreadsUpdated(threads, e.userId)),
      onError: (Object err) => add(ChatThreadsFailed(err.toString())),
    );
  }

  void _onThreadsUpdated(ChatThreadsUpdated e, Emitter<ChatState> emit) {
    // Unread computation needs Hive (async): queue it separately.
    add(ChatUnreadRefresh(e.threads, e.userId));
    emit(state.copyWith(threads: e.threads, isLoading: false));
  }

  void _onThreadsFailed(ChatThreadsFailed e, Emitter<ChatState> emit) {
    emit(state.copyWith(error: e.error, isLoading: false));
  }

  Future<void> _onMessages(ChatMessagesWatch e, Emitter<ChatState> emit) async {
    // Cancel the previous thread's subscription first: without this, rapid
    // switches leave overlapping streams delivering stale messages.
    await _messagesSub?.cancel();
    // Clear the previous thread's messages immediately so switching threads
    // never flashes stale content while the new snapshot loads.
    emit(
      state.copyWith(activeChatId: e.chatId, messages: const [], isLoading: true),
    );
    // Opening a thread marks it seen (clears its unread badge).
    await _markThreadSeen(
      MarkThreadSeenParams(chatId: e.chatId, userId: e.userId),
    );
    emit(
      state.copyWith(unreadChatIds: state.unreadChatIds.difference({e.chatId})),
    );
    _messagesSub = _watchMessages(e.chatId).listen(
      (messages) => add(ChatMessagesUpdated(e.chatId, messages)),
      onError: (Object err) => add(ChatMessagesFailed(e.chatId, err.toString())),
    );
  }

  void _onMessagesUpdated(ChatMessagesUpdated e, Emitter<ChatState> emit) {
    // Stale-thread guard: a late snapshot from the previously-open thread
    // must not overwrite the newly-opened thread's messages.
    if (e.chatId != state.activeChatId) return;
    emit(state.copyWith(messages: e.messages, isLoading: false));
  }

  void _onMessagesFailed(ChatMessagesFailed e, Emitter<ChatState> emit) {
    if (e.chatId != state.activeChatId) return;
    emit(state.copyWith(error: e.error, isLoading: false));
  }

  Future<void> _onThreadClosed(
    ChatThreadClosed e,
    Emitter<ChatState> emit,
  ) async {
    await _messagesSub?.cancel();
    _messagesSub = null;
    emit(
      state.copyWith(messages: const [], isLoading: false, clearActiveChat: true),
    );
  }

  /// Drops subscriptions and returns to the initial state so the next
  /// signed-in user never sees the previous user's threads or messages.
  Future<void> _onReset(ChatReset e, Emitter<ChatState> emit) async {
    await _threadsSub?.cancel();
    _threadsSub = null;
    await _messagesSub?.cancel();
    _messagesSub = null;
    emit(const ChatState());
  }

  /// Clears the open thread without dispatching an event (for hosts that
  /// already hold the bloc, e.g. route observers).
  Future<void> clearActiveChat() async {
    add(const ChatThreadClosed());
  }

  Future<void> _onUnreadRefresh(
    ChatUnreadRefresh e,
    Emitter<ChatState> emit,
  ) async {
    try {
      final unread = await _getUnreadThreads(
        GetUnreadThreadsParams(threads: e.threads, currentUserId: e.userId),
      );
      final fresh = unread
          .difference(state.unreadChatIds)
          .where((id) => id != state.activeChatId);
      emit(state.copyWith(unreadChatIds: unread));
      final notify = _onNewMessage;
      if (notify != null) {
        for (final id in fresh) {
          for (final t in e.threads) {
            if (t.id == id) {
              try {
                await notify(t);
              } catch (e) {
                // Notification failures never break the chat flow.
                appLogger.warning('Chat notify failed: $e');
              }
            }
          }
        }
      }
    } catch (e) {
      // Badges are best-effort; logged for field debugging only.
      appLogger.warning('Chat unread refresh failed: $e');
    }
  }

  Future<void> _onSendText(ChatTextSend e, Emitter<ChatState> emit) async {
    try {
      await _sendTextMessage(
        SendTextParams(
          chatId: e.chatId,
          senderId: e.senderId,
          text: e.text,
        ),
      );
    } on Failure catch (f) {
      emit(state.copyWith(error: f.message));
    } catch (err) {
      emit(state.copyWith(error: err.toString()));
    }
  }

  Future<void> _onSendPhoto(ChatPhotoSend e, Emitter<ChatState> emit) async {
    try {
      await _sendPhotoMessage(
        SendPhotoParams(
          chatId: e.chatId,
          senderId: e.senderId,
          localImagePath: e.localImagePath,
        ),
      );
    } on Failure catch (f) {
      emit(state.copyWith(error: f.message));
    } catch (err) {
      emit(state.copyWith(error: err.toString()));
    }
  }
}
