import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';

/// Provides a shared singleton bloc from get_it *without creating it*
/// (value provider — the bloc is never closed here). Replaces the repeated
/// `BlocProvider.value(GetIt.instance<XBloc>())` page wrappers.
class ProvideBloc<B extends BlocBase<dynamic>> extends StatelessWidget {
  const ProvideBloc({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<B>.value(
      value: GetIt.instance<B>(),
      child: child,
    );
  }
}
