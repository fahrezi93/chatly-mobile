import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'providers/inbox_provider.dart';

class ChatInboxScreen extends ConsumerWidget {
  const ChatInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxState = ref.watch(inboxProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: inboxState.when(
        data: (chats) {
          if (chats.isEmpty) {
            return const Center(child: Text('No chats yet. Start a conversation!'));
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(inboxProvider.future),
            child: ListView.separated(
              itemCount: chats.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
              itemBuilder: (context, index) {
                final chat = chats[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: chat.avatar != null && chat.avatar!.isNotEmpty
                        ? NetworkImage(chat.avatar!) // CachedNetworkImage used later
                        : null,
                    child: chat.avatar == null || chat.avatar!.isEmpty
                        ? const Icon(Icons.person, color: Colors.white, size: 30)
                        : null,
                  ),
                  title: Text(
                    chat.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    chat.lastMessage ?? (chat.isGroup ? 'Group Created' : 'Say hi!'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        chat.lastMessageTime != null 
                            ? DateFormat('HH:mm').format(chat.lastMessageTime!) 
                            : '',
                        style: TextStyle(
                          color: chat.unreadCount > 0 ? Theme.of(context).colorScheme.primary : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      if (chat.unreadCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: Text(
                              chat.unreadCount.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    context.push('/chat/${chat.id}', extra: chat);
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(inboxProvider.future),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/contacts');
        },
        child: const Icon(Icons.message),
      ),
    );
  }
}
