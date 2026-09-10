import 'package:firebase_core/firebase_core.dart';
// AuthException comes from core's own exceptions.dart; gotrue's same-named
// type is hidden to avoid ambiguity (Supabase auth errors surface as
// PostgrestException/StorageException here, both handled below).
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import 'exceptions.dart';
import 'failures.dart';

/// Maps backend errors to the [Failure] taxonomy so blocs can rely on
/// `on Failure` instead of formatting raw exceptions. Unknown and
/// programming errors become [ServerFailure] (loud, with the original text).
Never mapDataError(Object e) {
  if (e is Failure) throw e;
  if (e is FirebaseException) {
    throw ServerFailure(e.message ?? 'Request failed');
  }
  if (e is PostgrestException) throw ServerFailure(e.message);
  if (e is StorageException) throw ServerFailure(e.message);
  throw ServerFailure(e.toString());
}

/// Auth variant of [mapDataError]. Passes cancellation through untouched —
/// callers handle `AuthCancelledException` with a silent branch first.
Never mapAuthError(Object e) {
  if (e is Failure) throw e;
  if (e is AuthCancelledException) throw e;
  if (e is AuthException) throw AuthFailure(e.message);
  throw ServerFailure(e.toString());
}
