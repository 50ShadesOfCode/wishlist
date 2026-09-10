import 'package:equatable/equatable.dart';

import '../../domain/entities/profile.dart';

class ProfileState extends Equatable {
  const ProfileState({this.profile, this.isLoading = false, this.error});

  final Profile? profile;
  final bool isLoading;
  final String? error;

  static const _profileSentinel = Object();

  ProfileState copyWith({
    Object? profile = _profileSentinel,
    bool? isLoading,
    String? error,
  }) => ProfileState(
    // `profile: null` explicitly clears; omitted preserves. `error` clears
    // on any copy without an explicit value (transient UI message).
    profile: identical(profile, _profileSentinel)
        ? this.profile
        : profile as Profile?,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );

  @override
  List<Object?> get props => [profile, isLoading, error];
}
