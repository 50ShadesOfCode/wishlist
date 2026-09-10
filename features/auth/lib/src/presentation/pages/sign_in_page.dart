import 'package:core_ui/core_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key, this.onGoSignUp, this.onGoReset, this.onSuccess});

  final VoidCallback? onGoSignUp;
  final VoidCallback? onGoReset;
  final VoidCallback? onSuccess;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (_, s) {
          if (s.status == AuthStatus.authenticated) widget.onSuccess?.call();
          if (s.error != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(s.error!)));
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: FormBuilder(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppTextField(
                    name: 'email',
                    label: 'Email',
                    hint: 'you@mail.com',
                  ),
                  const SizedBox(height: 12),
                  FormBuilderTextField(
                    name: 'password',
                    obscureText: _obscure,
                    validator: FormBuilderValidators.required(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'Sign in',
                    isLoading: state.isLoading,
                    onPressed: () {
                      if (_formKey.currentState?.saveAndValidate() ?? false) {
                        final v = _formKey.currentState!.value;
                        context.read<AuthBloc>().add(
                          SignInRequested(
                            v['email'] as String,
                            v['password'] as String,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Continue with Google',
                    outlined: true,
                    icon: Icons.g_mobiledata,
                    onPressed: () => context.read<AuthBloc>().add(
                      const GoogleSignInRequested(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Continue with Apple',
                    outlined: true,
                    icon: Icons.apple,
                    onPressed: () => context.read<AuthBloc>().add(
                      const AppleSignInRequested(),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onGoReset,
                    child: const Text('Forgot password?'),
                  ),
                  TextButton(
                    onPressed: widget.onGoSignUp,
                    child: const Text("Don't have an account? Sign up"),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
