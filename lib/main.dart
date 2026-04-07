import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'features/call/presentation/providers/call_provider.dart';

void main() {
  runApp(
    // ProviderScope is required for Riverpod
    const ProviderScope(
      child: ChatlyApp(),
    ),
  );
}

class ChatlyApp extends ConsumerWidget {
  const ChatlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the GoRouter instance from the provider
    final goRouter = ref.watch(routerProvider);

    // Global listener for incoming calls
    ref.listen<CallState>(callProvider, (previous, next) {
      if (next.status == CallStatus.ringing && !next.isCaller) {
        // If we received an incoming call, push the call screen
        // We only trigger this once when transitioning into ringing state.
        if (previous?.status != CallStatus.ringing) {
           goRouter.push('/call');
        }
      }
    });

    return MaterialApp.router(
      title: 'Chatly',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB), // A nice blue accent color
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system, // Automatically adapt to system preferences
      routerConfig: goRouter,
    );
  }
}
