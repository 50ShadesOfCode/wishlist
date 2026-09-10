import 'package:material_ui/material_ui.dart';

import '../../domain/entities/chat_message.dart';

/// Single chat message bubble, right-aligned for own messages.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
  });

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final m = message;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
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
                errorBuilder: (_, _, _) => const Icon(Icons.image),
              ),
            if (m.text != null) Text(m.text!),
          ],
        ),
      ),
    );
  }
}
