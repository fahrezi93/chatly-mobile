import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../auth/presentation/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState is AuthSuccess ? authState.user : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[300],
              backgroundImage: user?.avatar != null && user!.avatar!.isNotEmpty
                  ? CachedNetworkImageProvider(user.avatar!)
                  : null,
              child: user?.avatar == null || user!.avatar!.isEmpty
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            title: Text(user?.name ?? 'Account Profile', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(user?.email ?? 'Manage your details'),
            onTap: () => context.push('/profile'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () {
              ref.read(authProvider.notifier).logout();
              // Routing constraint in app_router will automatically kick us out to login
            },
          ),
        ],
      ),
    );
  }
}
