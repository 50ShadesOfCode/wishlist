import 'package:core_ui/core_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../utils/thread_label.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';

/// Chat thread list UI. Requires a [ChatBloc] above it in the tree
/// (provided by [ChatListPage]).
class ChatListView extends StatefulWidget {
  const ChatListView({super.key, required this.userId, this.onOpenThread});

  final String userId;
  final void Function(String chatId)? onOpenThread;

  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  @override
  void initState() {
    super.initState();
    // Dispatched once here so rebuilds don't create duplicate Firestore
    // subscriptions.
    BlocProvider.of<ChatBloc>(context).add(ChatThreadWatch(widget.userId));
  }

  @override
  void didUpdateWidget(ChatListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      BlocProvider.of<ChatBloc>(context).add(ChatThreadWatch(widget.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('secret_chats'.tr())),
      body: AppErrorListener<ChatBloc, ChatState>(
        errorOf: (s) => s.error,
        child: BlocBuilder<ChatBloc, ChatState>(
          builder: (context, state) {
            if (state.isLoading && state.threads.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.threads.isEmpty) {
              return Center(child: Text('no_chats'.tr()));
            }
            return ListView.builder(
              itemCount: state.threads.length,
              itemBuilder: (context, i) {
                final t = state.threads[i];
                final unread = state.unreadChatIds.contains(t.id);
                // Prefer the wish-name snapshot; fall back to the safe id
                // label for threads created before it existed.
                final title = t.wishlistItemName.isNotEmpty
                    ? t.wishlistItemName
                    : threadLabel(t.wishlistItemId);
                final subtitle = t.lastMessageText?.isNotEmpty == true
                    ? t.lastMessageText!
                    : '${t.participantIds.length} participants';
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.chat_bubble)),
                  title: Text(
                    title,
                    style: unread
                        ? const TextStyle(fontWeight: FontWeight.bold)
                        : null,
                  ),
                  subtitle: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: unread
                      ? Icon(
                          Icons.fiber_manual_record,
                          size: 12,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => widget.onOpenThread?.call(t.id),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
