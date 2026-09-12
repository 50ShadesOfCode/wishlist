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
///
/// google_sign_in v7: [GoogleSignIn] is a process-wide singleton
/// ([GoogleSignIn.instance]) requiring a one-time async [GoogleSignIn.initialize]
/// before use; authentication (who the user is) is separate from authorization
/// (scope grants for access tokens).
class SocialAuthDataSource {
  SocialAuthDataSource(this._auth, {this.googleServerClientId});
  final FirebaseAuth _auth;

  /// OAuth Web client ID passed as `serverClientId` to Google initialize().
  /// Null preserves default behavior; Android needs the Web client ID from
  /// the Firebase console for `idToken` to be populated.
  final String? googleServerClientId;

  GoogleSignIn get _google => GoogleSignIn.instance;
  bool _googleInitialized = false;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await _google.initialize(serverClientId: googleServerClientId);
    _googleInitialized = true;
  }

  Future<UserModel> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();
      // Platforms without custom-UI authentication (e.g. web) fall back to
      // a lightweight (possibly silent) authentication returning null when
      // no previous grant exists — treated as a cancel like v6's null.
      final GoogleSignInAccount? account = _google.supportsAuthenticate()
          ? await _google.authenticate(scopeHint: const ['email'])
          : await _google.attemptLightweightAuthentication();
      if (account == null) {
        throw const AuthCancelledException();
      }
      final googleAuth = account.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw const AuthException(
          'Google sign in failed (missing ID token — check serverClientId)',
        );
      }
      // Access tokens now need an explicit scope grant; fall back to
      // ID-token-only (sufficient for Firebase) when the grant fails.
      String? accessToken;
      try {
        final authorization = await account.authorizationClient
            .authorizeScopes(const ['email']);
        accessToken = authorization.accessToken;
      } catch (_) {
        accessToken = null;
      }
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      final user = cred.user;
      if (user == null) throw const AuthException('Google sign in failed');
      return toUserModel(user);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCancelledException();
      }
      throw AuthException(e.description ?? 'Google sign in failed');
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

  /// Best-effort Google session clear; never blocks Firebase sign-out.
  Future<void> signOut() async {
    try {
      await _ensureGoogleInitialized();
      await _google.signOut();
    } catch (_) {
      // Ignore: Google SDK state must not fail sign-out.
    }
  }
}
