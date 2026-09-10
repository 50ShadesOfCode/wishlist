import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Bottom-tab scaffold hosting the wishlist/chats/following/profile branches.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.card_giftcard),
            label: 'wishlist'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble),
            label: 'chats'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            label: 'following'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person),
            label: 'profile'.tr(),
          ),
        ],
      ),
    );
  }
}
