import 'package:core/core.dart';

import '../entities/profile.dart';
import '../repositories/profile_repository.dart';
// NB: replay needs payload parsing, so it imports the model. In-package
// only — data/ stays out of the barrel (see profile.dart).
import '../../data/models/profile_model.dart';

class GetProfileUseCase implements UseCase<Profile?, String> {
  GetProfileUseCase(this._repo);
  final ProfileRepository _repo;

  @override
  Future<Profile?> call(String userId) => _repo.getProfile(userId);
}

class UpdateProfileUseCase implements UseCase<Profile, Profile> {
  UpdateProfileUseCase(this._repo);
  final ProfileRepository _repo;

  @override
  Future<Profile> call(Profile profile) => _repo.updateProfile(profile);
}

class UploadAvatarParams {
  const UploadAvatarParams({required this.userId, required this.filePath});
  final String userId;
  final String filePath;
}

class UploadAvatarUseCase implements UseCase<String, UploadAvatarParams> {
  UploadAvatarUseCase(this._repo);
  final ProfileRepository _repo;

  @override
  Future<String> call(UploadAvatarParams params) =>
      _repo.uploadAvatar(params.userId, params.filePath);
}

class RemoveAvatarUseCase implements UseCase<Profile, String> {
  RemoveAvatarUseCase(this._repo);
  final ProfileRepository _repo;

  @override
  Future<Profile> call(String userId) => _repo.removeAvatar(userId);
}

class DeleteUploadedAvatarUseCase implements UseCase<void, String> {
  DeleteUploadedAvatarUseCase(this._repo);
  final ProfileRepository _repo;

  @override
  Future<void> call(String avatarUrl) =>
      _repo.deleteUploadedAvatar(avatarUrl);
}

class IsUsernameTakenParams {
  const IsUsernameTakenParams({
    required this.username,
    required this.excludeUserId,
  });
  final String username;
  final String excludeUserId;
}

class IsUsernameTakenUseCase implements UseCase<bool, IsUsernameTakenParams> {
  IsUsernameTakenUseCase(this._repo);
  final ProfileRepository _repo;

  @override
  Future<bool> call(IsUsernameTakenParams params) => _repo.isUsernameTaken(
    params.username,
    params.excludeUserId,
  );
}

class DeleteProfileUseCase implements UseCase<void, String> {
  DeleteProfileUseCase(this._repo);
  final ProfileRepository _repo;

  @override
  Future<void> call(String userId) => _repo.deleteAccount(userId);
}

/// Replays one queued offline op (see [OutboxService]). Keeps the app layer
/// free of data models: payload parsing lives in the owning feature.
class ReplayProfileOpUseCase implements UseCase<void, OutboxOperation> {
  ReplayProfileOpUseCase(this._repo);
  final ProfileRepository _repo;

  @override
  Future<void> call(OutboxOperation op) async {
    if (OutboxKind.fromValue(op.kind) != OutboxKind.profileUpdate) {
      throw ServerFailure('Unknown outbox op: ${op.kind}');
    }
    await _repo.updateProfile(ProfileModel.fromJson(op.payload));
  }
}
