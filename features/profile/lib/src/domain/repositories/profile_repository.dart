import '../entities/profile.dart';

abstract class ProfileRepository {
  Future<Profile?> getProfile(String userId);
  Future<Profile> updateProfile(Profile profile);
  Future<String> uploadAvatar(String userId, String filePath);
  Future<Profile> removeAvatar(String userId);
  Future<bool> isUsernameTaken(String username, String excludeUserId);
  Future<void> deleteAccount(String userId);

  /// Best-effort removal of an uploaded avatar by URL (upload rollback).
  Future<void> deleteUploadedAvatar(String avatarUrl);
}
