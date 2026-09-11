import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bridges Firebase Auth into a Supabase session.
///
/// The app signs users in with Firebase, but Supabase tables are protected
/// by RLS keyed on `user_metadata.firebase_uid`. This service exchanges the
/// Firebase ID token for a Supabase session via the `firebase-bridge` Edge
/// Function and installs it on the Supabase client, so all subsequent
/// Supabase calls carry the JWT. Skips the network round-trip when a
/// session for the same Firebase user is already installed (the client
/// auto-refreshes it from the stored refresh token).
class SupabaseSessionBridge {
  SupabaseSessionBridge(this._supabase, this._firebase);

  final SupabaseClient _supabase;
  final FirebaseAuth _firebase;

  String? _bridgedForUid;

  /// Installs a Supabase session for the current Firebase user. Skips the
  /// network round-trip when a session for the same user is already
  /// installed, unless [forceRefresh] forces a fresh Firebase ID token and a
  /// new bridge exchange (used after 401/expiry).
  Future<void> ensureSession({bool forceRefresh = false}) async {
    final fbUser = _firebase.currentUser;
    if (fbUser == null) return;

    if (!forceRefresh) {
      final current = _supabase.auth.currentSession;
      final bridgedUid =
          current?.user.userMetadata?['firebase_uid'] as String?;
      if (current != null && bridgedUid == fbUser.uid) {
        _bridgedForUid = fbUser.uid;
        return;
      }
      if (_bridgedForUid == fbUser.uid && current != null) return;
    }

    final idToken = await fbUser.getIdToken(forceRefresh);
    final res = await _supabase.functions.invoke(
      'firebase-bridge',
      body: {'firebase_token': idToken},
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    // The Edge Function reports failures inside the payload (HTTP 200 with
    // an `error` field); installing a session from it would silently keep
    // RLS identity broken.
    final bridgeError = data['error'];
    if (bridgeError != null) {
      throw Exception('firebase-bridge: $bridgeError');
    }
    final refreshToken = data['refresh_token'];
    if (refreshToken is! String || refreshToken.isEmpty) {
      throw Exception('firebase-bridge: missing refresh_token');
    }
    await _supabase.auth.setSession(refreshToken);
    _bridgedForUid = fbUser.uid;
  }

  Future<void> clear() async {
    _bridgedForUid = null;
    await _supabase.auth.signOut();
  }
}
