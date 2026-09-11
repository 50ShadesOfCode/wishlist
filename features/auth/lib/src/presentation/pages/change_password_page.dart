import 'package:core_ui/core_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:go_router/go_router.dart';

/// Change-password screen. Self-contained (local loading/error state,
/// result via [onChange]); needs no bloc provider.
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
      await widget.onChange(v['current'] as String, v['next'] as String);
      // context.pop (not Navigator.pop): this page lives under a
      // StatefulShellRoute where Navigator.pop would escape the branch.
      if (mounted) context.pop();
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
                validator: AppValidators.requiredField,
                decoration: InputDecoration(labelText: 'current_password'.tr()),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'next',
                obscureText: true,
                validator: AppValidators.password,
                decoration: InputDecoration(labelText: 'new_password'.tr()),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
