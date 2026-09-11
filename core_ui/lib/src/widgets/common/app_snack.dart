import 'package:material_ui/material_ui.dart';

/// Single home for transient messages. Replaces hand-rolled
/// `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))` blocks.
void showAppSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

/// Snackbar with an action button (e.g. "Open settings" for permanently
/// denied permissions).
void showAppSnackAction(
  BuildContext context,
  String message, {
  required String actionLabel,
  required VoidCallback onAction,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(label: actionLabel, onPressed: onAction),
    ),
  );
}
