import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../bloc/auth_bloc.dart';
import 'sign_in_form.dart';

/// Provides the shared [AuthBloc] singleton and renders [SignInForm].
/// Keeps BlocProvider wiring out of the router.
class SignInPage extends StatelessWidget {
  const SignInPage({
    super.key,
    this.onGoSignUp,
    this.onGoReset,
    this.onSuccess,
  });

  final VoidCallback? onGoSignUp;
  final VoidCallback? onGoReset;
  final VoidCallback? onSuccess;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: GetIt.instance<AuthBloc>(),
      child: SignInForm(
        onGoSignUp: onGoSignUp,
        onGoReset: onGoReset,
        onSuccess: onSuccess,
      ),
    );
  }
}
