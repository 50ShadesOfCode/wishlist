import 'package:equatable/equatable.dart';

import '../../domain/entities/profile.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();
  @override
  List<Object?> get props => [];
}

class ProfileLoaded extends ProfileEvent {
  const ProfileLoaded(this.userId);
  final String userId;
}

class ProfileUpdated extends ProfileEvent {
  const ProfileUpdated(this.profile);
  final Profile profile;
}

/// Picked-but-not-yet-uploaded avatar file. The bloc uploads it to storage
/// first, then persists the public URL (never a device-local path).
class ProfileAvatarPicked extends ProfileEvent {
  const ProfileAvatarPicked(this.userId, this.filePath);
  final String userId;
  final String filePath;

  @override
  List<Object?> get props => [userId, filePath];
}
