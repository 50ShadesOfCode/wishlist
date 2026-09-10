import 'package:equatable/equatable.dart';

import '../../domain/entities/app_user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
    this.isLoading = false,
  });

  final AuthStatus status;
  final AppUser? user;
  final String? error;
  final bool isLoading;

  static const _userSentinel = Object();

  AuthState copyWith({
    AuthStatus? status,
    Object? user = _userSentinel,
    String? error,
    bool? isLoading,
  }) => AuthState(
    status: status ?? this.status,
    // `user: null` explicitly clears; omitted preserves. `error` clears
    // on any copy without an explicit value (transient UI message).
    user: identical(user, _userSentinel) ? this.user : user as AppUser?,
    error: error,
    isLoading: isLoading ?? this.isLoading,
  );

  @override
  List<Object?> get props => [status, user, error, isLoading];
}
