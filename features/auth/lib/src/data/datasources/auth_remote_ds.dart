import 'package:core/core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/user_model.dart';

/// Firebase-backed remote data source for auth:
/// email/password, Google and Apple. Supabase is used for DB only.
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._auth, this._googleSignIn);
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  UserModel _toModel(User user, {String? fallbackEmail}) => UserModel(
    id: user.uid,
    email: user.email ?? fallbackEmail ?? '',
    displayName: user.displayName,
    photoUrl: user.photoURL,
  );

  Never _throwAuth(FirebaseAuthException e) {
    throw AuthException(_messageFor(e));
  }

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Wrong email or password';
      case 'email-already-in-use':
        return 'Email is already in use';
      case 'weak-password':
        return 'Password is too weak';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'requires-recent-login':
        return 'Please sign in again to complete this action';
      case 'network-request-failed':
        return 'Network error, please try again';
      default:
        return e.message ?? 'Authentication failed';
    }
  }

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
      return _toModel(user, fallbackEmail: email);
    } on FirebaseAuthException catch (e) {
      _throwAuth(e);
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
      return _toModel(user, fallbackEmail: email);
    } on FirebaseAuthException catch (e) {
      _throwAuth(e);
    }
  }

  Future<UserModel> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const AuthException('Google sign in cancelled');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      final user = cred.user;
      if (user == null) throw const AuthException('Google sign in failed');
      return _toModel(user);
    } on FirebaseAuthException catch (e) {
      _throwAuth(e);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  Future<UserModel> signInWithApple() async {
    try {
      final appleCred = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final oauthCred = OAuthProvider('apple.com').credential(
        idToken: appleCred.identityToken,
        accessToken: appleCred.authorizationCode,
      );
      final cred = await _auth.signInWithCredential(oauthCred);
      final user = cred.user;
      if (user == null) throw const AuthException('Apple sign in failed');
      return _toModel(user);
    } on FirebaseAuthException catch (e) {
      _throwAuth(e);
    } on AuthException {
      rethrow;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AuthException('Apple sign in cancelled');
      }
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      _throwAuth(e);
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
      _throwAuth(e);
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
      _throwAuth(e);
    }
    // Sign out only after a successful delete. The Supabase profile row is
    // removed separately by the caller *before* this (while authenticated).
    await signOut();
  }

  UserModel? currentUser() {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _toModel(user);
  }

  Stream<UserModel?> authStateChanges() => _auth.authStateChanges().map(
    (user) => user == null ? null : _toModel(user),
  );
}
