import 'package:core_ui/core_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/entities/wishlist_item.dart';
import '../bloc/wishlist_bloc.dart';
import 'wishlist_edit_form.dart';

/// Provides the shared [WishlistBloc] singleton and renders
/// [WishlistEditForm]. Keeps BlocProvider wiring out of the router.
class WishlistEditPage extends StatelessWidget {
  const WishlistEditPage({
    super.key,
    required this.ownerId,
    this.existing,
    this.onDiscuss,
  });

  final String ownerId;
  final WishlistItem? existing;

  /// Opens (creating if needed) the secret chat for [existing]. Null hides
  /// the discuss action. Wired by the app router, which owns navigation and
  /// the chat repository.
  final Future<void> Function(WishlistItem item)? onDiscuss;

  @override
  Widget build(BuildContext context) {
    return ProvideBloc<WishlistBloc>(
      child: WishlistEditForm(
        ownerId: ownerId,
        existing: existing,
        onDiscuss: onDiscuss,
      ),
    );
  }
}
