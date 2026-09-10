import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc(this._repo) : super(const ProfileState()) {
    on<ProfileLoaded>(_onLoad);
    on<ProfileUpdated>(_onUpdate);
    on<ProfileAvatarPicked>(_onAvatarPicked);
  }

  final ProfileRepository _repo;

  Future<void> _onLoad(ProfileLoaded e, Emitter<ProfileState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final p = await _repo.getProfile(e.userId);
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
      final p = await _repo.updateProfile(e.profile);
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
      final url = await _repo.uploadAvatar(e.userId, e.filePath);
      final current =
          state.profile ?? Profile(userId: e.userId, username: 'user');
      final p = await _repo.updateProfile(
        current.copyWith(avatarUrl: url),
      );
      emit(state.copyWith(profile: p, isLoading: false));
    } catch (err) {
      // Upload failure keeps the previous avatar; only the error surfaces.
      emit(state.copyWith(isLoading: false, error: err.toString()));
    }
  }
}
