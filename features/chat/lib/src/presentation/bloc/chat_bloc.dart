import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc(this._repo, {this._onNewMessage}) : super(const ChatState()) {
    on<ChatThreadWatch>(_onThreads);
    on<ChatMessagesWatch>(_onMessages);
    on<ChatTextSend>(_onSendText);
    on<ChatPhotoSend>(_onSendPhoto);
    on<ChatUnreadRefresh>(_onUnreadRefresh);
  }

  final ChatRepository _repo;

  /// Fired once per newly-unread thread (wired to local notifications).
  /// Skipped for the currently open thread.
  final Future<void> Function(ChatThread thread)? _onNewMessage;

  Future<void> _onThreads(ChatThreadWatch e, Emitter<ChatState> emit) async {
    await emit.forEach<List<ChatThread>>(
      _repo.watchThreadsForUser(e.userId),
      onData: (threads) {
        // Unread computation needs Hive (async): queue it separately.
        add(ChatUnreadRefresh(threads, e.userId));
        return state.copyWith(threads: threads);
      },
      onError: (err, _) => state.copyWith(error: err.toString()),
    );
  }

  Future<void> _onMessages(ChatMessagesWatch e, Emitter<ChatState> emit) async {
    // Clear the previous thread's messages immediately so switching threads
    // never flashes stale content while the new snapshot loads.
    emit(state.copyWith(activeChatId: e.chatId, messages: const []));
    // Opening a thread marks it seen (clears its unread badge).
    await _repo.markThreadSeen(e.chatId);
    emit(
      state.copyWith(unreadChatIds: state.unreadChatIds.difference({e.chatId})),
    );
    await emit.forEach<List<ChatMessage>>(
      _repo.watchMessages(e.chatId),
      onData: (messages) => state.copyWith(messages: messages),
      onError: (err, _) => state.copyWith(error: err.toString()),
    );
  }

  Future<void> _onUnreadRefresh(
    ChatUnreadRefresh e,
    Emitter<ChatState> emit,
  ) async {
    try {
      final unread = await _repo.unreadThreadIds(e.threads, e.userId);
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
      await _repo.sendText(
        chatId: e.chatId,
        senderId: e.senderId,
        text: e.text,
      );
    } on Failure catch (f) {
      emit(state.copyWith(error: f.message));
    } catch (err) {
      emit(state.copyWith(error: err.toString()));
    }
  }

  Future<void> _onSendPhoto(ChatPhotoSend e, Emitter<ChatState> emit) async {
    try {
      await _repo.sendPhoto(
        chatId: e.chatId,
        senderId: e.senderId,
        localImagePath: e.localPath,
      );
    } on Failure catch (f) {
      emit(state.copyWith(error: f.message));
    } catch (err) {
      emit(state.copyWith(error: err.toString()));
    }
  }
}
