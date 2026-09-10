import 'package:material_ui/material_ui.dart';

import '../../theme/app_dimens.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final card = Padding(
      padding: padding ?? const EdgeInsets.all(AppDimens.l),
      child: child,
    );
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusL),
      ),
      child: onTap != null
          ? InkWell(
              borderRadius: BorderRadius.circular(AppDimens.radiusL),
              onTap: onTap,
              child: card,
            )
          : card,
    );
  }
}
