import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/contacts_provider.dart';
import '../../../chat/domain/chat_room_model.dart';
import '../../domain/contact_user_model.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(contactSearchQueryProvider.notifier).updateQuery(query);
  }

  void _startChat(ContactUser user) {
    // Navigate strictly to the chat room mimicking a previously created ChatRoom
    final dummyRoom = ChatRoom(
      id: user.id, // backend handles mapping receiverId inside private-message event
      name: user.displayName,
      avatar: user.profilePicture,
      isGroup: false,
      unreadCount: 0,
    );

    context.push('/chat/${user.id}', extra: dummyRoom);
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(contactsSearchProvider);
    final isSearching = ref.watch(contactSearchQueryProvider).trim().length >= 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by username or name...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blue,
              child: Icon(Icons.group_add, color: Colors.white),
            ),
            title: const Text('Create New Group', style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              context.push('/contacts/create_group');
            },
          ),
          const Divider(),

          // Results
          Expanded(
            child: !isSearching 
              ? Center(child: Text('Type at least 2 characters to search users', style: TextStyle(color: Colors.grey[600])))
              : searchResults.when(
                  data: (users) {
                    if (users.isEmpty) {
                      return const Center(child: Text('No users found.'));
                    }
                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[300],
                            backgroundImage: user.profilePicture != null 
                              ? CachedNetworkImageProvider(user.profilePicture!)
                              : null,
                            child: user.profilePicture == null 
                              ? const Icon(Icons.person, color: Colors.white)
                              : null,
                          ),
                          title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('@${user.username}'),
                          trailing: user.isOnline 
                            ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle))
                            : null,
                          onTap: () => _startChat(user),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(child: Text('Error: $error')),
              ),
          ),
        ],
      ),
    );
  }
}
