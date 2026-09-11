import 'package:core_ui/core_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Sign-in screen UI. Requires an [AuthBloc] above it in the tree
/// (provided by [SignInPage]). Post-login navigation is owned by the
/// go_router auth guard (`refreshListenable`), never by this form.
class SignInForm extends StatefulWidget {
  const SignInForm({super.key, this.onGoSignUp, this.onGoReset});

  final VoidCallback? onGoSignUp;
  final VoidCallback? onGoReset;

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('sign_in'.tr())),
      body: AppErrorListener<AuthBloc, AuthState>(
        errorOf: (s) => s.error,
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: FormBuilder(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    name: 'email',
                    label: 'email'.tr(),
                    hint: 'you@mail.com',
                    keyboardType: TextInputType.emailAddress,
                    validators: AppValidators.email,
                  ),
                  const SizedBox(height: 12),
                  FormBuilderTextField(
                    name: 'password',
                    obscureText: _obscure,
                    validator: AppValidators.requiredField,
                    decoration: InputDecoration(
                      labelText: 'password'.tr(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'sign_in'.tr(),
                    isLoading: state.isLoading,
                    onPressed: () {
                      if (_formKey.currentState?.saveAndValidate() ?? false) {
                        final v = _formKey.currentState!.value;
                        BlocProvider.of<AuthBloc>(context).add(
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
                    label: 'continue_google'.tr(),
                    outlined: true,
                    icon: Icons.g_mobiledata,
                    onPressed: () =>
                        BlocProvider.of<AuthBloc>(context)
                            .add(const GoogleSignInRequested()),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'continue_apple'.tr(),
                    outlined: true,
                    icon: Icons.apple,
                    onPressed: () =>
                        BlocProvider.of<AuthBloc>(context)
                            .add(const AppleSignInRequested()),
                  ),
                  TextButton(
                    onPressed: widget.onGoReset,
                    child: Text('forgot_password'.tr()),
                  ),
                  TextButton(
                    onPressed: widget.onGoSignUp,
                    child: Text('no_account_signup'.tr()),
                  ),
                ],
              ),
            ),
          );
          },
        ),
      ),
    );
  }
}
