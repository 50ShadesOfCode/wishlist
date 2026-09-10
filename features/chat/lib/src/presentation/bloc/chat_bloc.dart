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
    on<ChatMessagesWatch>(_onMessages);
    on<ChatMessagesUpdated>(_onMessagesUpdated);
    on<ChatMessagesFailed>(_onMessagesFailed);
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

  /// Active message subscription. Replaced (with cancel) on every
  /// [ChatMessagesWatch] so rapid thread switches never leave overlapping
  /// streams writing into each other's state.
  StreamSubscription<List<ChatMessage>>? _messagesSub;

  @override
  Future<void> close() {
    _messagesSub?.cancel();
    return super.close();
  }

  Future<void> _onThreads(ChatThreadWatch e, Emitter<ChatState> emit) async {
    emit(state.copyWith(isLoading: true));
    await emit.forEach<List<ChatThread>>(
      _watchThreads(e.userId),
      onData: (threads) {
        // Unread computation needs Hive (async): queue it separately.
        add(ChatUnreadRefresh(threads, e.userId));
        return state.copyWith(threads: threads, isLoading: false);
      },
      onError: (err, _) =>
          state.copyWith(error: err.toString(), isLoading: false),
    );
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
    await _markThreadSeen(e.chatId);
    emit(
      state.copyWith(unreadChatIds: state.unreadChatIds.difference({e.chatId})),
    );
    _messagesSub = _watchMessages(e.chatId).listen(
      (messages) => add(ChatMessagesUpdated(messages)),
      onError: (Object err) => add(ChatMessagesFailed(err.toString())),
    );
  }

  void _onMessagesUpdated(ChatMessagesUpdated e, Emitter<ChatState> emit) {
    emit(state.copyWith(messages: e.messages, isLoading: false));
  }

  void _onMessagesFailed(ChatMessagesFailed e, Emitter<ChatState> emit) {
    emit(state.copyWith(error: e.error, isLoading: false));
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
              } catch (_) {
                // Notification failures never break the chat flow.
              }
            }
          }
        }
      }
    } catch (_) {
      // Badges are best-effort; ignore.
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
