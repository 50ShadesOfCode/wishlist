import 'package:core_ui/core_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';

/// Secret discussion UI. Requires a [ChatBloc] above it in the tree
/// (provided by [ChatThreadPage]).
class ChatThreadView extends StatefulWidget {
  const ChatThreadView({
    super.key,
    required this.chatId,
    required this.currentUserId,
  });

  final String chatId;
  final String currentUserId;

  @override
  State<ChatThreadView> createState() => _ChatThreadViewState();
}

class _ChatThreadViewState extends State<ChatThreadView> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    BlocProvider.of<ChatBloc>(context).add(ChatMessagesWatch(widget.chatId));
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
    BlocProvider.of<ChatBloc>(context)
        .add(ChatPhotoSend(widget.chatId, widget.currentUserId, file.path));
  }

  void _send(String text) {
    BlocProvider.of<ChatBloc>(context).add(
      ChatTextSend(widget.chatId, widget.currentUserId, text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('secret_discussion'.tr())),
      body: AppErrorListener<ChatBloc, ChatState>(
        errorOf: (s) => s.error,
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
                      return MessageBubble(
                        message: m,
                        mine: m.senderId == widget.currentUserId,
                      );
                    },
                  );
                },
              ),
            ),
            MessageInput(
              controller: _controller,
              onPickPhoto: _pickPhoto,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}
