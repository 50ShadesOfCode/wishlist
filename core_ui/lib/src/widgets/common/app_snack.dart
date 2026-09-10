import 'package:material_ui/material_ui.dart';

/// Single home for transient messages. Replaces hand-rolled
/// `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))` blocks.
void showAppSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}
