import 'package:core_ui/core_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../bloc/auth_bloc.dart';
import 'sign_up_form.dart';

/// Provides the shared [AuthBloc] singleton and renders [SignUpForm].
/// Keeps BlocProvider wiring out of the router.
class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key, this.onGoSignIn});

  final VoidCallback? onGoSignIn;

  @override
  Widget build(BuildContext context) {
    return ProvideBloc<AuthBloc>(child: SignUpForm(onGoSignIn: onGoSignIn));
  }
}
