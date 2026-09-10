import 'package:core_ui/core_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/entities/profile.dart';

/// Avatar display with tap-to-change and optional remove action.
class AvatarSection extends StatelessWidget {
  const AvatarSection({
    super.key,
    required this.profile,
    required this.isLoading,
    required this.onPick,
    required this.onRemove,
  });

  final Profile profile;
  final bool isLoading;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPick,
          child: AppAvatar(imageUrl: profile.avatarUrl, radius: 48),
        ),
        const SizedBox(height: 8),
        Text('tap_avatar'.tr()),
        if (profile.avatarUrl != null)
          TextButton(
            onPressed: isLoading ? null : onRemove,
            child: Text('remove_photo'.tr()),
          ),
      ],
    );
  }
}
