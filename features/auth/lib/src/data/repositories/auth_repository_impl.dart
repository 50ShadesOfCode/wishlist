import 'dart:async';

import 'package:core/core.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_ds.dart';
import '../datasources/auth_remote_ds.dart';
import '../models/user_model.dart';

/// Firebase Auth repository. The Firebase SDK persists the session itself,
/// so no Supabase session/token handling is needed here.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._local);

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;

  Future<AppUser> _cacheAndReturn(UserModel user) async {
    await _local.cacheUser(user);
    return user;
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _remote.signUp(email: email, password: password);
      return await _cacheAndReturn(user);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _remote.signIn(email: email, password: password);
      return await _cacheAndReturn(user);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      final user = await _remote.signInWithGoogle();
      return await _cacheAndReturn(user);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<AppUser> signInWithApple() async {
    try {
      final user = await _remote.signInWithApple();
      return await _cacheAndReturn(user);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    await _remote.signOut();
    await _local.clear();
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      _remote.sendPasswordReset(email);

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _remote.changePassword(
    currentPassword: currentPassword,
    newPassword: newPassword,
  );

  @override
  Future<AppUser?> currentUser() async =>
      _remote.currentUser() ?? _local.cachedUser();

  @override
  Stream<AppUser?> authStateChanges() => _remote.authStateChanges();

  @override
  Future<void> deleteAccount() async {
    try {
      await _remote.deleteAccount();
      await _local.clear();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }
}
