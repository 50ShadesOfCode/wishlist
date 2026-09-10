import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import 'app_snack.dart';

/// Shows a bloc's transient `error` once per emission (fires only when the
/// extracted error changes to non-null, so rebuilds never re-fire it).
class AppErrorListener<B extends BlocBase<S>, S> extends StatelessWidget {
  const AppErrorListener({
    super.key,
    required this.errorOf,
    required this.child,
  });

  final String? Function(S state) errorOf;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<B, S>(
      listenWhen: (prev, curr) =>
          errorOf(prev) != errorOf(curr) && errorOf(curr) != null,
      listener: (context, state) => showAppSnack(context, errorOf(state)!),
      child: child,
    );
  }
}
