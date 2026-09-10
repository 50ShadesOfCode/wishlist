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

class SignUpUseCase implements UseCase<AppUser, SignInParams> {
  SignUpUseCase(this._repo);
  final AuthRepository _repo;

  @override
  Future<AppUser> call(SignInParams params) =>
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
