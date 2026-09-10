import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repo) : super(const AuthState()) {
    on<AuthChecked>(_onChecked);
    on<SignInRequested>(_onSignIn);
    on<SignUpRequested>(_onSignUp);
    on<GoogleSignInRequested>(_onGoogle);
    on<AppleSignInRequested>(_onApple);
    on<SignOutRequested>(_onSignOut);
    on<PasswordResetRequested>(_onReset);
    on<DeleteAccountRequested>(_onDeleteAccount);
  }

  final AuthRepository _repo;

  Future<void> _onChecked(AuthChecked e, Emitter<AuthState> emit) async {
    try {
      final user = await _repo.currentUser();
      emit(
        state.copyWith(
          status: user != null
              ? AuthStatus.authenticated
              : AuthStatus.unauthenticated,
          user: user,
        ),
      );
    } catch (_) {
      emit(state.copyWith(status: AuthStatus.unauthenticated, user: null));
    }
  }

  Future<void> _onSignIn(SignInRequested e, Emitter<AuthState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final user = await _repo.signIn(email: e.email, password: e.password);
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          isLoading: false,
        ),
      );
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, error: f.message));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onSignUp(SignUpRequested e, Emitter<AuthState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final user = await _repo.signUp(email: e.email, password: e.password);
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          isLoading: false,
        ),
      );
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, error: f.message));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onGoogle(
    GoogleSignInRequested e,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final user = await _repo.signInWithGoogle();
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          isLoading: false,
        ),
      );
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, error: f.message));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onApple(AppleSignInRequested e, Emitter<AuthState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final user = await _repo.signInWithApple();
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          isLoading: false,
        ),
      );
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, error: f.message));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onSignOut(SignOutRequested e, Emitter<AuthState> emit) async {
    await _repo.signOut();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  Future<void> _onDeleteAccount(
    DeleteAccountRequested e,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      // The caller deletes the Supabase profile row first (while the
      // Firebase session is still valid for the RLS bridge); this removes
      // the Firebase user and clears local caches.
      await _repo.deleteAccount();
      emit(const AuthState(status: AuthStatus.unauthenticated));
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, error: f.message));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onReset(
    PasswordResetRequested e,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _repo.sendPasswordReset(e.email);
      emit(state.copyWith(error: null));
    } on Failure catch (f) {
      emit(state.copyWith(error: f.message));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
