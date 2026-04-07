import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/auth_provider.dart';
import '../../data/chat_repository.dart';
import '../../domain/chat_room_model.dart';

final chatRepositoryProvider = Provider((ref) {
  return ChatRepository(ref.watch(dioClientProvider));
});

// A FutureProvider to load the chat list asynchronously.
// It watches authProvider so it automatically re-runs whenever auth state changes
// (e.g., after session is restored from SharedPreferences on startup).
final inboxProvider = FutureProvider<List<ChatRoom>>((ref) async {
  final authState = ref.watch(authProvider);

  // Auth is still restoring the session — keep the future pending (shows spinner).
  // When authProvider state changes, Riverpod will rebuild this provider automatically.
  if (authState is AuthLoading) {
    final completer = Completer<List<ChatRoom>>();
    ref.onDispose(() => completer.complete([])); // Clean up on rebuild
    return completer.future;
  }

  // User is authenticated — fetch the actual chat list from the backend
  if (authState is AuthSuccess) {
    final repo = ref.watch(chatRepositoryProvider);
    return repo.fetchChats(authState.user);
  }

  // AuthInitial or AuthError — not logged in, return empty list
  return [];
});

