import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';

/// Message composer row: photo button, text field, send button.
class MessageInput extends StatelessWidget {
  const MessageInput({
    super.key,
    required this.controller,
    required this.onPickPhoto,
    required this.onSend,
  });

  final TextEditingController controller;
  final VoidCallback onPickPhoto;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.photo_outlined),
            onPressed: onPickPhoto,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'message_hint'.tr(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              onSend(text);
              controller.clear();
            },
          ),
        ],
      ),
    );
  }
}
