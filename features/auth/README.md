# auth

Firebase authentication: email/password, Google and Apple sign-in, sign-out,
password reset/change, and account deletion. State via `AuthBloc` (driven by
per-operation use-cases); UI split into `*_page.dart` (provider wiring) and
`*_form.dart` (screens).

Internal package (`publish_to: none`).
