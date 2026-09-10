import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../utils/thread_label.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';

/// Shows [ChatState.error] once per emission (transient error semantics).
class _ChatErrorListener extends StatelessWidget {
  const _ChatErrorListener({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatBloc, ChatState>(
      listenWhen: (prev, curr) =>
          prev.error != curr.error && curr.error != null,
      listener: (context, state) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error!)),
      ),
      child: child,
    );
  }
}

class ChatListPage extends StatefulWidget {
  const ChatListPage({
    super.key,
    required this.userId,
    this.onOpenThread,
  });

  final String userId;
  final void Function(String chatId)? onOpenThread;

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  @override
  void initState() {
    super.initState();
    // Dispatched once here (not in build, not in the router builder) so
    // rebuilds don't create duplicate Firestore subscriptions.
    context.read<ChatBloc>().add(ChatThreadWatch(widget.userId));
  }

  @override
  void didUpdateWidget(ChatListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      context.read<ChatBloc>().add(ChatThreadWatch(widget.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secret chats')),
      body: _ChatErrorListener(
        child: BlocBuilder<ChatBloc, ChatState>(
          builder: (context, state) {
            if (state.threads.isEmpty) {
              return const Center(
                child: Text('No secret discussions yet.'),
              );
            }
            return ListView.builder(
              itemCount: state.threads.length,
              itemBuilder: (context, i) {
                final t = state.threads[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.chat_bubble)),
                  title: Text(threadLabel(t.wishlistItemId)),
                  subtitle: Text('${t.participantIds.length} participants'),
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

class ChatThreadPage extends StatefulWidget {
  const ChatThreadPage({
    super.key,
    required this.chatId,
    required this.currentUserId,
  });

  final String chatId;
  final String currentUserId;

  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(ChatMessagesWatch(widget.chatId));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    late final XFile? file;
    try {
      file = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (_) {
      // Permission denial etc.: stay silent.
      return;
    }
    if (file == null) return;
    if (!mounted) return;
    context.read<ChatBloc>().add(
      ChatPhotoSend(widget.chatId, widget.currentUserId, file.path),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secret discussion')),
      body: _ChatErrorListener(
        child: Column(
        children: [
          Expanded(
            child: BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: state.messages.length,
                  itemBuilder: (context, i) {
                    final m = state.messages[i];
                    final mine = m.senderId == widget.currentUserId;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: mine
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (m.imageUrl != null)
                              Image.network(
                                m.imageUrl!,
                                height: 160,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.image),
                              ),
                            if (m.text != null) Text(m.text!),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_outlined),
                  onPressed: _pickPhoto,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Message…',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    final text = _controller.text.trim();
                    if (text.isEmpty) return;
                    context.read<ChatBloc>().add(
                      ChatTextSend(
                        widget.chatId,
                        widget.currentUserId,
                        text,
                      ),
                    );
                    _controller.clear();
                  },
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}
