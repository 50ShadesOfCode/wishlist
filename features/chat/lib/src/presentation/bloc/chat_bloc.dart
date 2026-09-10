import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc(this._repo) : super(const ChatState()) {
    on<ChatThreadWatch>(_onThreads);
    on<ChatMessagesWatch>(_onMessages);
    on<ChatTextSend>(_onSendText);
    on<ChatPhotoSend>(_onSendPhoto);
  }

  final ChatRepository _repo;

  Future<void> _onThreads(ChatThreadWatch e, Emitter<ChatState> emit) async {
    await emit.forEach<List<ChatThread>>(
      _repo.watchThreadsForUser(e.userId),
      onData: (threads) => state.copyWith(threads: threads),
      onError: (err, _) => state.copyWith(error: err.toString()),
    );
  }

  Future<void> _onMessages(
    ChatMessagesWatch e,
    Emitter<ChatState> emit,
  ) async {
    // Clear the previous thread's messages immediately so switching threads
    // never flashes stale content while the new snapshot loads.
    emit(state.copyWith(activeChatId: e.chatId, messages: const []));
    await emit.forEach<List<ChatMessage>>(
      _repo.watchMessages(e.chatId),
      onData: (messages) => state.copyWith(messages: messages),
      onError: (err, _) => state.copyWith(error: err.toString()),
    );
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
