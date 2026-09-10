import 'package:core_ui/core_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:image_picker/image_picker.dart';

import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';
import '../../domain/entities/profile.dart';

/// Telegram-like combined Profile + Settings page.
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.userId,
    this.onLogout,
    this.onDeleteAccount,
    this.onChangeTheme,
    this.onChangePassword,
    this.isDark = false,
    this.initialLocale = const Locale('en'),
    this.supportedLocales = const [Locale('en'), Locale('ru')],
    this.onChangeLocale,
  });

  final String userId;
  final VoidCallback? onLogout;
  final Future<void> Function()? onDeleteAccount;
  final ValueChanged<bool>? onChangeTheme;
  final VoidCallback? onChangePassword;
  final bool isDark;
  final Locale initialLocale;
  final List<Locale> supportedLocales;
  final ValueChanged<Locale>? onChangeLocale;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormBuilderState>();
  late bool _dark;

  @override
  void initState() {
    super.initState();
    _dark = widget.isDark;
    context.read<ProfileBloc>().add(ProfileLoaded(widget.userId));
  }

  Future<void> _pickAvatar(Profile current) async {
    final picker = ImagePicker();
    late final XFile? file;
    try {
      file = await picker.pickImage(source: ImageSource.gallery);
    } catch (_) {
      // Permission denial etc.: stay silent, keep current avatar.
      return;
    }
    if (file == null) return;
    if (!mounted) return;
    // Uploaded by the bloc; the stored avatar_url becomes a public URL,
    // never a device-local path.
    context.read<ProfileBloc>().add(
      ProfileAvatarPicked(current.userId, file.path),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('profile_settings'.tr())),
      body: BlocListener<ProfileBloc, ProfileState>(
        listenWhen: (prev, curr) =>
            prev.error != curr.error && curr.error != null,
        listener: (context, state) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error!)),
        ),
        child: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          final profile =
              state.profile ??
              Profile(userId: widget.userId, username: 'user');
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => _pickAvatar(profile),
                  child: AppAvatar(
                    imageUrl: profile.avatarUrl,
                    radius: 48,
                  ),
                ),
                const SizedBox(height: 8),
                Text('tap_avatar'.tr()),
                const SizedBox(height: 16),
                FormBuilder(
                  key: _formKey,
                  initialValue: {
                    'username': profile.username,
                    'city': profile.city,
                  },
                  child: Column(
                    children: [
                      FormBuilderTextField(
                        name: 'username',
                        // Mirrors Validators.isValidUsername (3..30 chars).
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                          FormBuilderValidators.minLength(3),
                          FormBuilderValidators.maxLength(30),
                        ]),
                        decoration: InputDecoration(
                          labelText: 'username'.tr(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FormBuilderDateTimePicker(
                        name: 'dob',
                        initialValue: profile.dateOfBirth,
                        inputType: InputType.date,
                        decoration: InputDecoration(
                          labelText: 'dob'.tr(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FormBuilderTextField(
                        name: 'city',
                        decoration: InputDecoration(labelText: 'city'.tr()),
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'save_profile'.tr(),
                        isLoading: state.isLoading,
                        onPressed: () {
                          if (_formKey.currentState?.saveAndValidate() ??
                              false) {
                            final v = _formKey.currentState!.value;
                            context.read<ProfileBloc>().add(
                              ProfileUpdated(
                                profile.copyWith(
                                  username: v['username'] as String,
                                  dateOfBirth: v['dob'] as DateTime?,
                                  city: v['city'] as String?,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 32),
                SwitchListTile(
                  title: Text('dark_theme'.tr()),
                  value: _dark,
                  onChanged: (v) {
                    setState(() => _dark = v);
                    widget.onChangeTheme?.call(v);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: Text('language'.tr()),
                  trailing: DropdownButton<Locale>(
                    value: widget.supportedLocales.contains(context.locale)
                        ? context.locale
                        : widget.initialLocale,
                    underline: const SizedBox.shrink(),
                    items: widget.supportedLocales
                        .map(
                          (l) => DropdownMenuItem(
                            value: l,
                            child: Text(l.languageCode.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (l) {
                      if (l != null) widget.onChangeLocale?.call(l);
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text('change_password'.tr()),
                  onTap: widget.onChangePassword,
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: Text('logout'.tr()),
                  onTap: widget.onLogout,
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: Text(
                    'delete_account'.tr(),
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('delete_confirm_title'.tr()),
                        content: Text('delete_confirm_body'.tr()),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('cancel'.tr()),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text('delete'.tr()),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await widget.onDeleteAccount?.call();
                  },
                ),
              ],
            ),
          );
        },
        ),
      ),
    );
  }
}
