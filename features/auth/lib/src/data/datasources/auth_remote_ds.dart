import 'package:core/core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_model.dart';
import 'auth_social_ds.dart';

/// Firebase-backed remote data source for auth:
/// email/password flows live here, Google/Apple in [SocialAuthDataSource].
/// Supabase is used for DB only.
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._auth, GoogleSignIn googleSignIn)
    : _social = SocialAuthDataSource(_auth, googleSignIn);
  final FirebaseAuth _auth;
  final SocialAuthDataSource _social;

  Future<UserModel> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user == null) throw const AuthException('Sign up failed');
      return toUserModel(user, fallbackEmail: email);
    } on FirebaseAuthException catch (e) {
      throwAuthError(e);
    }
  }

  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user == null) throw const AuthException('Sign in failed');
      return toUserModel(user, fallbackEmail: email);
    } on FirebaseAuthException catch (e) {
      throwAuthError(e);
    }
  }

  Future<UserModel> signInWithGoogle() => _social.signInWithGoogle();

  Future<UserModel> signInWithApple() => _social.signInWithApple();

  Future<void> signOut() async {
    await _social.signOut();
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throwAuthError(e);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('No user');
    final email = user.email;
    if (email == null) {
      throw const AuthException('Password change needs an email account');
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throwAuthError(e);
    }
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('No user');
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      // Delete failed (e.g. requires-recent-login): keep the session so the
      // user can re-authenticate and retry instead of being signed out with
      // the account — and its data — still present.
      throwAuthError(e);
    }
    // Sign out only after a successful delete. The Supabase profile row is
    // removed separately by the caller *before* this (while authenticated).
    await signOut();
  }

  UserModel? currentUser() {
    final user = _auth.currentUser;
    if (user == null) return null;
    return toUserModel(user);
  }
}
