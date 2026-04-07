import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/dio_client.dart';
import 'auth_model.dart';

class AuthRepository {
  final DioClient _dioClient;

  AuthRepository(this._dioClient);

  Future<AuthUser> login(String email, String password) async {
    try {
      final response = await _dioClient.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final data = response.data;
      final user = AuthUser.fromJson(data['user'] ?? data);
      
      // The backend probably returns the token like `{ token: '...', user: {...} }`
      final token = data['token'] ?? user.token;

      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await prefs.setString('auth_user', jsonEncode(user.copyWith(token: token).toJson()));
      }

      return user.copyWith(token: token);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<AuthUser> register(String name, String email, String password) async {
    try {
      final response = await _dioClient.dio.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
      });

      final data = response.data;
      final user = AuthUser.fromJson(data['user'] ?? data);
      final token = data['token'] ?? user.token;

      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await prefs.setString('auth_user', jsonEncode(user.copyWith(token: token).toJson()));
      }

      return user.copyWith(token: token);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
  }

  /// Restores user session from SharedPreferences (used on app startup)
  Future<AuthUser?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('auth_user');
    if (userJson != null && userJson.isNotEmpty) {
      try {
        return AuthUser.fromJson(jsonDecode(userJson));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<AuthUser> updateProfile(
    String userId, {
    String? displayName,
    String? email,
    String? bio,
    String? status,
    String? profilePicturePath,
  }) async {
    try {
      final formData = FormData.fromMap({
        if (displayName != null) 'displayName': displayName,
        if (email != null) 'email': email,
        if (bio != null) 'bio': bio,
        if (status != null) 'status': status,
        if (profilePicturePath != null)
          'profilePicture': await MultipartFile.fromFile(profilePicturePath),
      });

      final response = await _dioClient.dio.put(
        '/users/$userId',
        data: formData,
      );

      return AuthUser.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response != null && e.response?.data != null) {
      final data = e.response?.data;
      if (data is Map && data.containsKey('message')) {
        return data['message'];
      }
    }
    return 'An unexpected error occurred. Please try again.';
  }
}
