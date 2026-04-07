import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

// Optional: for routing if we want to force logout via GoRouter,
// but for simple state management, we can clear prefs and let Riverpod
// or the UI handle it at restart, or use an event bus.
// Here we'll just clear the session.

class DioClient {
  // Local backend URL depending on the platform
  static final String baseUrl = !kIsWeb && Platform.isAndroid 
      ? 'http://10.0.2.2:5000/api' 
      : 'http://localhost:5000/api';
  
  final Dio _dio;

  DioClient() : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    responseType: ResponseType.json,
  )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Retrieve token from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        // Handle global errors, e.g., token expiration (401)
        if (e.response?.statusCode == 401) {
          // Clear session on 401 Unauthorized so the app forces user to log in again
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('auth_token');
          await prefs.remove('auth_user');
        }
        return handler.next(e);
      },
    ));
  }

  Dio get dio => _dio;
}
