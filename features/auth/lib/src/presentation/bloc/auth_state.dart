import 'package:equatable/equatable.dart';

import '../../domain/entities/app_user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
    this.isLoading = false,
    this.passwordResetSent = false,
  });

  final AuthStatus status;
  final AppUser? user;
  final String? error;
  final bool isLoading;

  /// Set after a successful password-reset request so the page can show a
  /// confirmation exactly once (cleared together with [error]).
  final bool passwordResetSent;

  static const _userSentinel = Object();

  AuthState copyWith({
    AuthStatus? status,
    Object? user = _userSentinel,
    String? error,
    bool? isLoading,
    bool? passwordResetSent,
  }) => AuthState(
    status: status ?? this.status,
    // `user: null` explicitly clears; omitted preserves. `error` clears
    // on any copy without an explicit value (transient UI message).
    user: identical(user, _userSentinel) ? this.user : user as AppUser?,
    error: error,
    isLoading: isLoading ?? this.isLoading,
    passwordResetSent: passwordResetSent ?? this.passwordResetSent,
  );

  @override
  List<Object?> get props => [
    status,
    user,
    error,
    isLoading,
    passwordResetSent,
  ];
}
