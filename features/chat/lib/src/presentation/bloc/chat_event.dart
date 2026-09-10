import 'package:equatable/equatable.dart';

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
  const ChatPhotoSend(this.chatId, this.senderId, this.localPath);
  final String chatId;
  final String senderId;
  final String localPath;
}
