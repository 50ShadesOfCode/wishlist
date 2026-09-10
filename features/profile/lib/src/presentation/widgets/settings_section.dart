import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';

/// Theme, locale, password, logout and danger-zone rows.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.isDark,
    required this.onThemeChanged,
    required this.initialLocale,
    required this.supportedLocales,
    required this.onChangeLocale,
    required this.onChangePassword,
    required this.onLogout,
    required this.onDeleteAccount,
  });

  final bool isDark;
  final ValueChanged<bool> onThemeChanged;
  final Locale initialLocale;
  final List<Locale> supportedLocales;
  final ValueChanged<Locale>? onChangeLocale;
  final VoidCallback? onChangePassword;
  final VoidCallback? onLogout;
  final Future<void> Function()? onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 32),
        SwitchListTile(
          title: Text('dark_theme'.tr()),
          value: isDark,
          onChanged: onThemeChanged,
        ),
        ListTile(
          leading: const Icon(Icons.language_outlined),
          title: Text('language'.tr()),
          trailing: DropdownButton<Locale>(
            value: supportedLocales.contains(context.locale)
                ? context.locale
                : initialLocale,
            underline: const SizedBox.shrink(),
            items: supportedLocales
                .map(
                  (l) => DropdownMenuItem(
                    value: l,
                    child: Text(l.languageCode.toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: (l) {
              if (l != null) onChangeLocale?.call(l);
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: Text('change_password'.tr()),
          onTap: onChangePassword,
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text('logout'.tr()),
          onTap: onLogout,
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
            if (ok == true) await onDeleteAccount?.call();
          },
        ),
      ],
    );
  }
}
