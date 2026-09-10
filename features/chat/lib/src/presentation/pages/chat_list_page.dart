import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../bloc/chat_bloc.dart';
import 'chat_list_view.dart';

/// Provides the shared [ChatBloc] singleton and renders [ChatListView].
/// Keeps BlocProvider wiring out of the router.
class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key, required this.userId, this.onOpenThread});

  final String userId;
  final void Function(String chatId)? onOpenThread;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: GetIt.instance<ChatBloc>(),
      child: ChatListView(userId: userId, onOpenThread: onOpenThread),
    );
  }
}
