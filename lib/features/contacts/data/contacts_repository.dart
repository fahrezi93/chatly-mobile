import '../../../core/network/dio_client.dart';
import '../domain/contact_user_model.dart';

class ContactsRepository {
  final DioClient _dioClient;

  ContactsRepository(this._dioClient);

  Future<List<ContactUser>> searchUsers(String query) async {
    try {
      final response = await _dioClient.dio.get('/users/search', queryParameters: {'q': query});
      final List data = response.data;
      return data.map((json) => ContactUser.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }

  Future<void> createGroup({
    required String name, 
    required List<String> memberIds, 
    required String creatorId,
    String description = '',
  }) async {
    try {
      await _dioClient.dio.post('/groups', data: {
        'name': name,
        'description': description,
        'creator': creatorId,
        'members': memberIds,
      });
    } catch (e) {
      throw Exception('Failed to create group: $e');
    }
  }
}
