import 'package:core_ui/core_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../bloc/profile_bloc.dart';
import 'profile_form.dart';

/// Provides the shared [ProfileBloc] singleton and renders [ProfileForm].
/// Keeps BlocProvider wiring out of the router.
class ProfilePage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ProvideBloc<ProfileBloc>(
      child: ProfileForm(
        userId: userId,
        onLogout: onLogout,
        onDeleteAccount: onDeleteAccount,
        onChangeTheme: onChangeTheme,
        onChangePassword: onChangePassword,
        isDark: isDark,
        initialLocale: initialLocale,
        supportedLocales: supportedLocales,
        onChangeLocale: onChangeLocale,
      ),
    );
  }
}
