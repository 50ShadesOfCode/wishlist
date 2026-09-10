import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';

/// Pending-offline-mutations banner with a manual "sync now" action.
/// Hidden when no outbox is wired or nothing is pending.
class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key, required this.outbox, required this.onSyncNow});

  final OutboxService? outbox;
  final Future<void> Function()? onSyncNow;

  @override
  Widget build(BuildContext context) {
    final box = outbox;
    final sync = onSyncNow;
    if (box == null || sync == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: box,
      builder: (context, _) {
        final n = box.pending;
        if (n == 0) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('${'pending_sync'.tr()} ($n)')),
              TextButton(onPressed: () => sync(), child: Text('sync_now'.tr())),
            ],
          ),
        );
      },
    );
  }
}
