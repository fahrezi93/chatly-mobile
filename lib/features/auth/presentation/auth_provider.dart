import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../data/auth_model.dart';
import '../data/auth_repository.dart';

// Provide DioClient
final dioClientProvider = Provider((ref) => DioClient());

// Provide AuthRepository
final authRepositoryProvider = Provider((ref) {
  return AuthRepository(ref.watch(dioClientProvider));
});

abstract class AuthState {}
class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthSuccess extends AuthState {
  final AuthUser user;
  AuthSuccess(this.user);
}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// The Notifier class (Riverpod 3.0 compatible)
class AuthNotifier extends Notifier<AuthState> {
  late AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    // Restore session asynchronously on startup.
    // We set AuthLoading immediately so dependent providers (e.g. inboxProvider)
    // know to wait rather than resolve with an empty list.
    _restoreSession();
    return AuthLoading();
  }

  Future<void> _restoreSession() async {
    final user = await _repository.restoreSession();
    if (user != null) {
      state = AuthSuccess(user);
    } else {
      state = AuthInitial(); // No saved session, show login
    }
  }

  Future<void> login(String email, String password) async {
    state = AuthLoading();
    try {
      final user = await _repository.login(email, password);
      state = AuthSuccess(user);
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = AuthLoading();
    try {
      final user = await _repository.register(name, email, password);
      state = AuthSuccess(user);
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = AuthInitial();
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? bio,
    String? status,
    String? profilePicturePath,
  }) async {
    final currentState = state;
    if (currentState is AuthSuccess) {
      try {
        final updatedUser = await _repository.updateProfile(
          currentState.user.id,
          displayName: name,
          email: email,
          bio: bio,
          status: status,
          profilePicturePath: profilePicturePath,
        );
        
        // Preserve the token from the old user state since backend update might not return it
        final mergedUser = updatedUser.copyWith(token: currentState.user.token);
        state = AuthSuccess(mergedUser);
      } catch (e) {
        throw Exception(e);
      }
    }
  }
}

// Provide AuthNotifier
final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
