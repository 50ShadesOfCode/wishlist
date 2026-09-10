import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../bloc/auth_bloc.dart';
import 'sign_up_form.dart';

/// Provides the shared [AuthBloc] singleton and renders [SignUpForm].
/// Keeps BlocProvider wiring out of the router.
class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key, this.onGoSignIn, this.onSuccess});

  final VoidCallback? onGoSignIn;
  final VoidCallback? onSuccess;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: GetIt.instance<AuthBloc>(),
      child: SignUpForm(onGoSignIn: onGoSignIn, onSuccess: onSuccess),
    );
  }
}
