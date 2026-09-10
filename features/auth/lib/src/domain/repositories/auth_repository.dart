import '../entities/app_user.dart';

abstract class AuthRepository {
  Future<AppUser> signUp({required String email, required String password});
  Future<AppUser> signIn({required String email, required String password});
  Future<AppUser> signInWithGoogle();
  Future<AppUser> signInWithApple();
  Future<void> signOut();
  Future<void> sendPasswordReset(String email);
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<AppUser?> currentUser();
  Stream<AppUser?> authStateChanges();
  Future<void> deleteAccount();
}
