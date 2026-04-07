import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/home/presentation/main_layout_screen.dart';
import '../../features/chat/presentation/screens/chat_room_screen.dart';
import '../../features/chat/domain/chat_room_model.dart';
import '../../features/call/presentation/screens/voice_call_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/contacts/presentation/screens/contacts_screen.dart';
import '../../features/contacts/presentation/screens/create_group_screen.dart';

// Provides the GoRouter instance
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (BuildContext context, GoRouterState state) async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      // If no token and not already on the login/register screen, redirect to login
      if ((token == null || token.isEmpty) && !isLoggingIn) {
        return '/login';
      }

      // If has token and tries to access login/register, redirect to home
      if ((token != null && token.isNotEmpty) && isLoggingIn) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const MainLayoutScreen(),
      ),
      GoRoute(
        path: '/chat/:roomId',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          final extra = state.extra as ChatRoom?;
          return ChatRoomScreen(roomId: roomId, chatData: extra);
        },
      ),
      GoRoute(
        path: '/call',
        builder: (context, state) => const VoiceCallScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/contacts',
        builder: (context, state) => const ContactsScreen(),
        routes: [
          GoRoute(
            path: 'create_group',
            builder: (context, state) => const CreateGroupScreen(),
          ),
        ],
      ),
    ],
  );
});
