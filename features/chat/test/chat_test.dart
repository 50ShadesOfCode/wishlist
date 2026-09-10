import 'package:flutter_test/flutter_test.dart';
import 'package:chat/src/data/models/chat_models.dart';
import 'package:chat/src/utils/thread_label.dart';
import 'package:chat/chat.dart';

void main() {
  test('ChatMessage model roundtrip', () {
    final m = ChatMessageModel(
      id: 'm1',
      chatId: 'c1',
      senderId: 'u1',
      text: 'hi',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    expect(m.toJson()['text'], 'hi');
  });

  test('threadLabel never throws', () {
    expect(threadLabel(''), 'Wish…');
    expect(threadLabel('abc'), 'Wish abc…');
    expect(threadLabel('abcdef'), 'Wish abcdef…');
    expect(threadLabel('abcdefghijklmnopqrstuvwxyz012345'), 'Wish abcdef…');
  });

  test('ChatState error clears on next copy without error', () {
    const s = ChatState(error: 'boom');
    expect(s.copyWith().error, isNull);
    expect(s.copyWith(error: 'boom').error, 'boom');
  });
}
