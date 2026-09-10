class ServerException implements Exception {
  const ServerException([this.message = 'Server error']);
  final String message;
}

class CacheException implements Exception {
  const CacheException([this.message = 'Cache error']);
  final String message;
}

class AuthException implements Exception {
  const AuthException([this.message = 'Auth error']);
  final String message;
}

class NotFoundException implements Exception {
  const NotFoundException([this.message = 'Not found']);
  final String message;
}

/// The user dismissed a system account picker (Google/Apple). Not an error:
/// callers translate this into a silent no-op, never an error snackbar.
class AuthCancelledException implements Exception {
  const AuthCancelledException();
}
