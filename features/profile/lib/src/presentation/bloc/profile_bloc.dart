import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/profile.dart';
import '../../domain/usecases/profile_usecases.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc({
    required this._getProfile,
    required this._updateProfile,
    required this._uploadAvatar,
    required this._removeAvatar,
    required this._isUsernameTaken,
  }) : super(const ProfileState()) {
    on<ProfileLoaded>(_onLoad);
    on<ProfileUpdated>(_onUpdate);
    on<ProfileAvatarPicked>(_onAvatarPicked);
    on<ProfileAvatarRemoved>(_onAvatarRemoved);
  }

  final GetProfileUseCase _getProfile;
  final UpdateProfileUseCase _updateProfile;
  final UploadAvatarUseCase _uploadAvatar;
  final RemoveAvatarUseCase _removeAvatar;
  final IsUsernameTakenUseCase _isUsernameTaken;

  Future<void> _onLoad(ProfileLoaded e, Emitter<ProfileState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final p = await _getProfile(e.userId);
      emit(state.copyWith(profile: p, isLoading: false));
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, error: f.message));
    } catch (err) {
      emit(state.copyWith(isLoading: false, error: err.toString()));
    }
  }

  Future<void> _onUpdate(ProfileUpdated e, Emitter<ProfileState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      if (await _isUsernameTaken(
        IsUsernameTakenParams(
          username: e.profile.username,
          excludeUserId: e.profile.userId,
        ),
      )) {
        emit(state.copyWith(isLoading: false, error: 'username_taken'.tr()));
        return;
      }
      final p = await _updateProfile(e.profile);
      emit(state.copyWith(profile: p, isLoading: false));
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, error: f.message));
    } catch (err) {
      emit(state.copyWith(isLoading: false, error: err.toString()));
    }
  }

  Future<void> _onAvatarPicked(
    ProfileAvatarPicked e,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final url = await _uploadAvatar(
        UploadAvatarParams(userId: e.userId, filePath: e.filePath),
      );
      final current =
          state.profile ?? Profile(userId: e.userId, username: 'user');
      final p = await _updateProfile(current.copyWith(avatarUrl: url));
      emit(state.copyWith(profile: p, isLoading: false));
    } catch (err) {
      // Upload failure keeps the previous avatar; only the error surfaces.
      emit(state.copyWith(isLoading: false, error: err.toString()));
    }
  }

  Future<void> _onAvatarRemoved(
    ProfileAvatarRemoved e,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final p = await _removeAvatar(e.userId);
      emit(state.copyWith(profile: p, isLoading: false));
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, error: f.message));
    } catch (err) {
      emit(state.copyWith(isLoading: false, error: err.toString()));
    }
  }
}
