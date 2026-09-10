import 'package:cupertino_ui/cupertino_ui.dart';

class CupertinoPrimaryButton extends StatelessWidget {
  const CupertinoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton.filled(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const CupertinoActivityIndicator()
          : Text(label),
    );
  }
}
