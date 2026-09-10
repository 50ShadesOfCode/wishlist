import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../bloc/auth_bloc.dart';
import 'reset_password_form.dart';

/// Provides the shared [AuthBloc] singleton and renders [ResetPasswordForm].
/// Keeps BlocProvider wiring out of the router.
class ResetPasswordPage extends StatelessWidget {
  const ResetPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: GetIt.instance<AuthBloc>(),
      child: const ResetPasswordForm(),
    );
  }
}
