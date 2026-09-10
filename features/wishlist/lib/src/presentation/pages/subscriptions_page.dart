import 'package:core_ui/core_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/entities/wishlist_item.dart';

class _TargetSection {
  const _TargetSection({
    required this.subscription,
    required this.name,
    required this.items,
  });

  final Subscription subscription;
  final String name;
  final List<WishlistItem> items;
}

/// Feed of visible items from subscribed users, with subscribe/unsubscribe.
///
/// All backend access goes through callbacks so this package stays decoupled
/// from auth/profile/chat: the app router wires them to the real repos.
class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({
    super.key,
    required this.userId,
    required this.onLoadSubscriptions,
    required this.onLoadItems,
    required this.onSubscribe,
    required this.onUnsubscribe,
    required this.resolveName,
    this.onDiscuss,
  });

  final String userId;
  final Future<List<Subscription>> Function() onLoadSubscriptions;

  /// Visible (non-hidden) items of one target user.
  final Future<List<WishlistItem>> Function(String targetUserId) onLoadItems;

  /// Subscribe/unsubscribe the current user to/from [targetUserId].
  final Future<void> Function(String targetUserId) onSubscribe;
  final Future<void> Function(String targetUserId) onUnsubscribe;

  /// Display name for a user id (best-effort; falls back to the id).
  final Future<String> Function(String userId) resolveName;

  /// Opens the secret chat for an item (wired to the chat repository).
  final Future<void> Function(WishlistItem item)? onDiscuss;

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  final _idController = TextEditingController();
  bool _loading = true;
  bool _adding = false;
  String? _error;
  List<_TargetSection> _sections = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final subs = await widget.onLoadSubscriptions();
      final sections = <_TargetSection>[];
      for (final s in subs) {
        String name;
        try {
          name = await widget.resolveName(s.targetUserId);
        } catch (_) {
          name = s.targetUserId;
        }
        List<WishlistItem> items;
        try {
          items = await widget.onLoadItems(s.targetUserId);
        } catch (_) {
          items = const [];
        }
        sections.add(_TargetSection(subscription: s, name: name, items: items));
      }
      if (mounted) {
        setState(() {
          _sections = sections;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _add() async {
    final id = _idController.text.trim();
    if (id.isEmpty || _adding) return;
    setState(() => _adding = true);
    try {
      await widget.onSubscribe(id);
      _idController.clear();
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'subscribe_failed'.tr()}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _remove(String targetUserId) async {
    try {
      await widget.onUnsubscribe(targetUserId);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('following'.tr())),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _idController,
                    decoration: InputDecoration(
                      labelText: 'user_id'.tr(),
                      hintText: 'following_hint'.tr(),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'add'.tr(),
                  onPressed: _adding ? null : _add,
                  icon: _adding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: LoadingShimmer(height: 120),
              )
            else if (_error != null)
              EmptyState(title: _error!, subtitle: 'pull_retry'.tr())
            else if (_sections.isEmpty)
              EmptyState(
                title: 'following_empty'.tr(),
                subtitle: 'following_hint'.tr(),
              )
            else
              for (final section in _sections) ...[
                Row(
                  children: [
                    CircleAvatar(
                      child: Text(
                        section.name.isNotEmpty
                            ? section.name[0].toUpperCase()
                            : '?',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        section.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'unfollow'.tr(),
                      icon: const Icon(Icons.person_remove_outlined),
                      onPressed: () =>
                          _remove(section.subscription.targetUserId),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final item in section.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                if (item.placeLabel != null)
                                  Text(item.placeLabel!),
                              ],
                            ),
                          ),
                          if (widget.onDiscuss != null)
                            IconButton(
                              tooltip: 'discuss_wish'.tr(),
                              icon: const Icon(Icons.chat_bubble_outline),
                              onPressed: () => widget.onDiscuss!(item),
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }
}
