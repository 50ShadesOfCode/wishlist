import 'package:core/core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/user_model.dart';

/// Maps Firebase errors to human-readable messages (shared with
/// [AuthRemoteDataSource]).
String authErrorMessage(FirebaseAuthException e) {
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

Never throwAuthError(FirebaseAuthException e) {
  throw AuthException(authErrorMessage(e));
}

UserModel toUserModel(User user, {String? fallbackEmail}) => UserModel(
  id: user.uid,
  email: user.email ?? fallbackEmail ?? '',
  displayName: user.displayName,
  photoUrl: user.photoURL,
);

/// Google + Apple sign-in via Firebase credentials.
class SocialAuthDataSource {
  SocialAuthDataSource(this._auth, this._googleSignIn);
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  Future<UserModel> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const AuthCancelledException();
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      final user = cred.user;
      if (user == null) throw const AuthException('Google sign in failed');
      return toUserModel(user);
    } on FirebaseAuthException catch (e) {
      throwAuthError(e);
    } on AuthCancelledException {
      rethrow;
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
      return toUserModel(user);
    } on FirebaseAuthException catch (e) {
      throwAuthError(e);
    } on AuthCancelledException {
      rethrow;
    } on AuthException {
      rethrow;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AuthCancelledException();
      }
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  Future<void> signOut() => _googleSignIn.signOut();
}
