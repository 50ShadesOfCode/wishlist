import 'package:core_ui/core_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../bloc/auth_bloc.dart';
import 'reset_password_form.dart';

/// Provides the shared [AuthBloc] singleton and renders [ResetPasswordForm].
/// Keeps BlocProvider wiring out of the router.
class ResetPasswordPage extends StatelessWidget {
  const ResetPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProvideBloc<AuthBloc>(child: ResetPasswordForm());
  }
}
