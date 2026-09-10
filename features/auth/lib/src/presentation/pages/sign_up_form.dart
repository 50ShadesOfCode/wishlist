import 'package:core_ui/core_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Sign-up screen UI. Requires an [AuthBloc] above it in the tree
/// (provided by [SignUpPage]).
class SignUpForm extends StatelessWidget {
  const SignUpForm({super.key, this.onGoSignIn, this.onSuccess});

  final VoidCallback? onGoSignIn;
  final VoidCallback? onSuccess;

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormBuilderState>();
    return Scaffold(
      appBar: AppBar(title: Text('sign_up'.tr())),
      body: AppErrorListener<AuthBloc, AuthState>(
        errorOf: (s) => s.error,
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, s) {
            if (s.status == AuthStatus.authenticated) onSuccess?.call();
          },
          builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: FormBuilder(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FormBuilderTextField(
                    name: 'email',
                    validator: AppValidators.email,
                    decoration: InputDecoration(labelText: 'email'.tr()),
                  ),
                  const SizedBox(height: 12),
                  FormBuilderTextField(
                    name: 'password',
                    obscureText: true,
                    validator: AppValidators.password,
                    decoration: InputDecoration(labelText: 'password'.tr()),
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'create_account'.tr(),
                    isLoading: state.isLoading,
                    onPressed: () {
                      if (formKey.currentState?.saveAndValidate() ?? false) {
                        final v = formKey.currentState!.value;
                        BlocProvider.of<AuthBloc>(context).add(
                          SignUpRequested(
                            v['email'] as String,
                            v['password'] as String,
                          ),
                        );
                      }
                    },
                  ),
                  TextButton(
                    onPressed: onGoSignIn,
                    child: Text('have_account_signin'.tr()),
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
