import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/contacts_provider.dart';
import '../../../auth/presentation/auth_provider.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedMembers = {};
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _createGroup() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group name is required')));
      return;
    }
    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one member')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(contactsRepositoryProvider);
      final authState = ref.read(authProvider);
      final currentUserId = authState is AuthSuccess ? authState.user.id : '';
      
      await repo.createGroup(
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        creatorId: currentUserId,
        memberIds: _selectedMembers.toList(),
      );

      if (mounted) {
        context.pop(); // Go back to previous screen
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group created successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create group: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(contactsSearchProvider);
    final isSearching = ref.watch(contactSearchQueryProvider).trim().length >= 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Group'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _createGroup,
              child: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Search Members', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Text('${_selectedMembers.length} selected'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => ref.read(contactSearchQueryProvider.notifier).updateQuery(val),
              decoration: InputDecoration(
                hintText: 'Type to search users...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: !isSearching 
              ? const Center(child: Text('Search and tap users to add them.'))
              : searchResults.when(
                  data: (users) {
                    if (users.isEmpty) return const Center(child: Text('No users found.'));
                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final isSelected = _selectedMembers.contains(user.id);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: user.profilePicture != null 
                              ? CachedNetworkImageProvider(user.profilePicture!)
                              : null,
                            child: user.profilePicture == null ? const Icon(Icons.person) : null,
                          ),
                          title: Text(user.displayName),
                          subtitle: Text('@${user.username}'),
                          trailing: Icon(
                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                            color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                          ),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedMembers.remove(user.id);
                              } else {
                                _selectedMembers.add(user.id);
                              }
                            });
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                ),
          ),
        ],
      ),
    );
  }
}
