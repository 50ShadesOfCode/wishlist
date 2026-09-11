import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/auth_usecases.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required this._getCurrentUser,
    required this._signIn,
    required this._signUp,
    required this._signInWithGoogle,
    required this._signInWithApple,
    required this._signOut,
    required this._sendPasswordReset,
    required this._deleteAccount,
  }) : super(const AuthState()) {
    on<AuthChecked>(_onChecked);
    on<SignInRequested>(_onSignIn);
    on<SignUpRequested>(_onSignUp);
    on<GoogleSignInRequested>(_onGoogle);
    on<AppleSignInRequested>(_onApple);
    on<SignOutRequested>(_onSignOut);
    on<PasswordResetRequested>(_onReset);
    on<PasswordResetConsumed>(_onResetConsumed);
    on<DeleteAccountRequested>(_onDeleteAccount);
  }

  final GetCurrentUserUseCase _getCurrentUser;
  final SignInUseCase _signIn;
  final SignUpUseCase _signUp;
  final GoogleSignInUseCase _signInWithGoogle;
  final AppleSignInUseCase _signInWithApple;
  final SignOutUseCase _signOut;
  final ResetPasswordUseCase _sendPasswordReset;
  final DeleteAccountUseCase _deleteAccount;

  Future<void> _onChecked(AuthChecked e, Emitter<AuthState> emit) async {
    try {
      final user = await _getCurrentUser(const NoParams());
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
      final user = await _signIn(SignInParams(email: e.email, password: e.password));
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
      final user = await _signUp(SignUpParams(email: e.email, password: e.password));
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
      final user = await _signInWithGoogle(const NoParams());
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          isLoading: false,
        ),
      );
    } on AuthCancelledFailure {
      // Picker dismissed: stop loading silently, no error snackbar.
      emit(state.copyWith(isLoading: false));
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, error: f.message));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onApple(AppleSignInRequested e, Emitter<AuthState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final user = await _signInWithApple(const NoParams());
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          isLoading: false,
        ),
      );
    } on AuthCancelledFailure {
      // Picker dismissed: stop loading silently, no error snackbar.
      emit(state.copyWith(isLoading: false));
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, error: f.message));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onSignOut(SignOutRequested e, Emitter<AuthState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      await _signOut(const NoParams());
      emit(const AuthState(status: AuthStatus.unauthenticated));
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, error: f.message));
    } catch (err) {
      emit(state.copyWith(isLoading: false, error: err.toString()));
    }
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
      await _deleteAccount(const NoParams());
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
    emit(
      state.copyWith(isLoading: true, error: null, passwordResetSent: false),
    );
    try {
      await _sendPasswordReset(e.email);
      // Success is signaled explicitly so the page shows the confirmation
      // only after the request actually completes.
      emit(state.copyWith(isLoading: false, passwordResetSent: true));
    } on Failure catch (f) {
      emit(state.copyWith(isLoading: false, error: f.message));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void _onResetConsumed(PasswordResetConsumed e, Emitter<AuthState> emit) {
    if (state.passwordResetSent) {
      emit(state.copyWith(passwordResetSent: false));
    }
  }
}
