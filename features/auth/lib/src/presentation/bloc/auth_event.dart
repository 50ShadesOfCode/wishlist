import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthChecked extends AuthEvent {
  const AuthChecked();
}

class SignInRequested extends AuthEvent {
  const SignInRequested(this.email, this.password);
  final String email;
  final String password;
}

class SignUpRequested extends AuthEvent {
  const SignUpRequested(this.email, this.password);
  final String email;
  final String password;
}

class GoogleSignInRequested extends AuthEvent {
  const GoogleSignInRequested();
}

class AppleSignInRequested extends AuthEvent {
  const AppleSignInRequested();
}

class SignOutRequested extends AuthEvent {
  const SignOutRequested();
}

class DeleteAccountRequested extends AuthEvent {
  const DeleteAccountRequested();
}

class PasswordResetRequested extends AuthEvent {
  const PasswordResetRequested(this.email);
  final String email;
}

/// Clears transient UI state ([AuthState.error], [AuthState.passwordResetSent])
/// after the page has displayed it, so rebuilds never re-fire snackbars.
class AuthErrorCleared extends AuthEvent {
  const AuthErrorCleared();
}
