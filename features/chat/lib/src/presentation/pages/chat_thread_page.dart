import 'package:core_ui/core_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../bloc/chat_bloc.dart';
import 'chat_thread_view.dart';

/// Provides the shared [ChatBloc] singleton and renders [ChatThreadView].
/// Keeps BlocProvider wiring out of the router.
class ChatThreadPage extends StatelessWidget {
  const ChatThreadPage({
    super.key,
    required this.chatId,
    required this.currentUserId,
  });

  final String chatId;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    return ProvideBloc<ChatBloc>(
      child: ChatThreadView(chatId: chatId, currentUserId: currentUserId),
    );
  }
}
