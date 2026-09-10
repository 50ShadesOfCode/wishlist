import 'package:core_ui/core_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class ResetPasswordPage extends StatelessWidget {
  const ResetPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormBuilderState>();
    return Scaffold(
      appBar: AppBar(title: Text('restore_password'.tr())),
      body: BlocConsumer<AuthBloc, AuthState>(
        listenWhen: (prev, curr) =>
            prev.error != curr.error && curr.error != null ||
            (!prev.passwordResetSent && curr.passwordResetSent),
        listener: (context, s) {
          if (s.error != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(s.error!)));
            context.read<AuthBloc>().add(const AuthErrorCleared());
          } else if (s.passwordResetSent) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('restore_sent'.tr())),
            );
            context.read<AuthBloc>().add(const AuthErrorCleared());
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
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(),
                      FormBuilderValidators.email(),
                    ]),
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
                        context.read<AuthBloc>().add(
                          PasswordResetRequested(email),
                        );
                      }
                    },
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

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key, required this.onChange});

  final Future<void> Function(String current, String next) onChange;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _sending = false;
  String? _error;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final v = _formKey.currentState!.value;
      await widget.onChange(
        v['current'] as String,
        v['next'] as String,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('change_password'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: FormBuilder(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormBuilderTextField(
                name: 'current',
                obscureText: true,
                validator: FormBuilderValidators.required(),
                decoration: InputDecoration(
                  labelText: 'current_password'.tr(),
                ),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'next',
                obscureText: true,
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(),
                  FormBuilderValidators.minLength(6),
                ]),
                decoration: InputDecoration(labelText: 'new_password'.tr()),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              AppButton(
                label: 'change_password'.tr(),
                isLoading: _sending,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
