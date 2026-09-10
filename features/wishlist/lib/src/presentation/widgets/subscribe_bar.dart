import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';

/// User-id input row with an add button for following someone.
class SubscribeBar extends StatelessWidget {
  const SubscribeBar({
    super.key,
    required this.controller,
    required this.adding,
    required this.onAdd,
  });

  final TextEditingController controller;
  final bool adding;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'user_id'.tr(),
              hintText: 'following_hint'.tr(),
            ),
            onSubmitted: (_) => onAdd(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'add'.tr(),
          onPressed: adding ? null : onAdd,
          icon: adding
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_add_outlined),
        ),
      ],
    );
  }
}
