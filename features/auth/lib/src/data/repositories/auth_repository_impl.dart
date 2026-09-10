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
    } catch (e) {
      mapAuthError(e);
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
    } catch (e) {
      mapAuthError(e);
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      final user = await _remote.signInWithGoogle();
      return await _cacheAndReturn(user);
    } on AuthCancelledException {
      // User dismissed the picker: silent, never an error snackbar.
      throw const AuthCancelledFailure();
    } catch (e) {
      mapAuthError(e);
    }
  }

  @override
  Future<AppUser> signInWithApple() async {
    try {
      final user = await _remote.signInWithApple();
      return await _cacheAndReturn(user);
    } on AuthCancelledException {
      // User dismissed the picker: silent, never an error snackbar.
      throw const AuthCancelledFailure();
    } catch (e) {
      mapAuthError(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _remote.signOut();
      await _local.clear();
    } catch (e) {
      mapAuthError(e);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _remote.sendPasswordReset(email);
    } catch (e) {
      mapAuthError(e);
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _remote.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } catch (e) {
      mapAuthError(e);
    }
  }

  @override
  Future<AppUser?> currentUser() async =>
      _remote.currentUser() ?? _local.cachedUser();

  @override
  Future<void> deleteAccount() async {
    try {
      await _remote.deleteAccount();
      await _local.clear();
    } catch (e) {
      mapAuthError(e);
    }
  }
}
