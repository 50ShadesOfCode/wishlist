import 'package:core_ui/core_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Restore-password screen UI. Requires an [AuthBloc] above it in the tree
/// (provided by [ResetPasswordPage]).
class ResetPasswordForm extends StatelessWidget {
  const ResetPasswordForm({super.key});

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormBuilderState>();
    return Scaffold(
      appBar: AppBar(title: Text('restore_password'.tr())),
      body: AppErrorListener<AuthBloc, AuthState>(
        errorOf: (s) => s.error,
        child: BlocConsumer<AuthBloc, AuthState>(
          listenWhen: (prev, curr) =>
              !prev.passwordResetSent && curr.passwordResetSent,
          listener: (context, s) {
            if (s.passwordResetSent) {
              showAppSnack(context, 'restore_sent'.tr());
            }
          },
          builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: FormBuilder(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('restore_hint'.tr()),
                  const SizedBox(height: 12),
                  FormBuilderTextField(
                    name: 'email',
                    validator: AppValidators.email,
                    decoration: InputDecoration(labelText: 'email'.tr()),
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'send_restore_link'.tr(),
                    isLoading: state.isLoading,
                    onPressed: () {
                      if (formKey.currentState?.saveAndValidate() ?? false) {
                        final email =
                            formKey.currentState!.value['email'] as String;
                        BlocProvider.of<AuthBloc>(context)
                            .add(PasswordResetRequested(email));
                      }
                    },
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
