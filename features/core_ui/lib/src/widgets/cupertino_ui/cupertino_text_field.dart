import 'package:cupertino_ui/cupertino_ui.dart';

class CupertinoInput extends StatelessWidget {
  const CupertinoInput({
    super.key,
    required this.placeholder,
    this.controller,
    this.obscureText = false,
  });

  final String placeholder;
  final TextEditingController? controller;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      obscureText: obscureText,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
