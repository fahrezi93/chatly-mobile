import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/contacts_repository.dart';
import '../../domain/contact_user_model.dart';
import '../../../auth/presentation/auth_provider.dart';

final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return ContactsRepository(dioClient);
});

class ContactSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void updateQuery(String newQuery) {
    state = newQuery;
  }
}

final contactSearchQueryProvider = NotifierProvider<ContactSearchQueryNotifier, String>(() {
  return ContactSearchQueryNotifier();
});

final contactsSearchProvider = FutureProvider.autoDispose<List<ContactUser>>((ref) async {
  final query = ref.watch(contactSearchQueryProvider);
  if (query.trim().length < 2) return [];

  final repo = ref.watch(contactsRepositoryProvider);
  
  final authState = ref.watch(authProvider);
  final currentUserId = authState is AuthSuccess ? authState.user.id : '';
  
  final users = await repo.searchUsers(query);
  
  // Exclude current user from results
  return users.where((u) => u.id != currentUserId).toList();
});
