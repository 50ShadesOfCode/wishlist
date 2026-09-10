import 'package:core_ui/core_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:image_picker/image_picker.dart';

import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';
import '../widgets/avatar_section.dart';
import '../widgets/settings_section.dart';
import '../../domain/entities/profile.dart';

/// Telegram-like combined Profile + Settings screen UI. Requires a
/// [ProfileBloc] above it in the tree (provided by [ProfilePage]).
class ProfileForm extends StatefulWidget {
  const ProfileForm({
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
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  final _formKey = GlobalKey<FormBuilderState>();
  late bool _dark;

  @override
  void initState() {
    super.initState();
    _dark = widget.isDark;
    BlocProvider.of<ProfileBloc>(context).add(ProfileLoaded(widget.userId));
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
    BlocProvider.of<ProfileBloc>(context)
        .add(ProfileAvatarPicked(current.userId, file.path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('profile_settings'.tr())),
      body: AppErrorListener<ProfileBloc, ProfileState>(
        errorOf: (s) => s.error,
        child: BlocBuilder<ProfileBloc, ProfileState>(
          builder: (context, state) {
            final profile =
                state.profile ??
                Profile(userId: widget.userId, username: 'user');
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                AvatarSection(
                  profile: profile,
                  isLoading: state.isLoading,
                  onPick: () => _pickAvatar(profile),
                  onRemove: () =>
                      BlocProvider.of<ProfileBloc>(context).add(
                        ProfileAvatarRemoved(profile.userId),
                      ),
                ),
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
                        validator: AppValidators.username,
                        decoration: InputDecoration(
                          labelText: 'username'.tr(),
                        ),
                      ),
                        const SizedBox(height: 12),
                        FormBuilderDateTimePicker(
                          name: 'dob',
                          initialValue: profile.dateOfBirth,
                          inputType: InputType.date,
                          validator: (v) {
                            if (v != null && v.isAfter(DateTime.now())) {
                              return 'dob_future'.tr();
                            }
                            return null;
                          },
                          decoration: InputDecoration(labelText: 'dob'.tr()),
                        ),
                        const SizedBox(height: 12),
                      FormBuilderTextField(
                        name: 'city',
                        validator: AppValidators.city,
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
                              BlocProvider.of<ProfileBloc>(context).add(
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
                  SettingsSection(
                    isDark: _dark,
                    onThemeChanged: (v) {
                      setState(() => _dark = v);
                      widget.onChangeTheme?.call(v);
                    },
                    initialLocale: widget.initialLocale,
                    supportedLocales: widget.supportedLocales,
                    onChangeLocale: widget.onChangeLocale,
                    onChangePassword: widget.onChangePassword,
                    onLogout: widget.onLogout,
                    onDeleteAccount: widget.onDeleteAccount,
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
