import 'package:core/core.dart';

import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

class SignInUseCase implements UseCase<AppUser, SignInParams> {
  SignInUseCase(this._repo);
  final AuthRepository _repo;

  @override
  Future<AppUser> call(SignInParams params) =>
      _repo.signIn(email: params.email, password: params.password);
}

class SignInParams {
  const SignInParams({required this.email, required this.password});
  final String email;
  final String password;
}

class SignUpParams {
  const SignUpParams({required this.email, required this.password});
  final String email;
  final String password;
}

class SignUpUseCase implements UseCase<AppUser, SignUpParams> {
  SignUpUseCase(this._repo);
  final AuthRepository _repo;

  @override
  Future<AppUser> call(SignUpParams params) =>
      _repo.signUp(email: params.email, password: params.password);
}

class SignOutUseCase implements UseCase<void, NoParams> {
  SignOutUseCase(this._repo);
  final AuthRepository _repo;

  @override
  Future<void> call(NoParams params) => _repo.signOut();
}

class ResetPasswordUseCase implements UseCase<void, String> {
  ResetPasswordUseCase(this._repo);
  final AuthRepository _repo;

  @override
  Future<void> call(String email) => _repo.sendPasswordReset(email);
}

class GoogleSignInUseCase implements UseCase<AppUser, NoParams> {
  GoogleSignInUseCase(this._repo);
  final AuthRepository _repo;

  @override
  Future<AppUser> call(NoParams params) => _repo.signInWithGoogle();
}

class AppleSignInUseCase implements UseCase<AppUser, NoParams> {
  AppleSignInUseCase(this._repo);
  final AuthRepository _repo;

  @override
  Future<AppUser> call(NoParams params) => _repo.signInWithApple();
}

class DeleteAccountUseCase implements UseCase<void, NoParams> {
  DeleteAccountUseCase(this._repo);
  final AuthRepository _repo;

  @override
  Future<void> call(NoParams params) => _repo.deleteAccount();
}

class GetCurrentUserUseCase implements UseCase<AppUser?, NoParams> {
  GetCurrentUserUseCase(this._repo);
  final AuthRepository _repo;

  @override
  Future<AppUser?> call(NoParams params) => _repo.currentUser();
}

class ChangePasswordParams {
  const ChangePasswordParams({
    required this.currentPassword,
    required this.newPassword,
  });
  final String currentPassword;
  final String newPassword;
}

class ChangePasswordUseCase implements UseCase<void, ChangePasswordParams> {
  ChangePasswordUseCase(this._repo);
  final AuthRepository _repo;

  @override
  Future<void> call(ChangePasswordParams params) => _repo.changePassword(
    currentPassword: params.currentPassword,
    newPassword: params.newPassword,
  );
}
