import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/auth_provider.dart';
import 'dio_client.dart';

class UploadService {
  final DioClient _dioClient;

  UploadService(this._dioClient);

  Future<UploadResult> uploadFile(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });

      final response = await _dioClient.dio.post(
        '/upload',
        data: formData,
        onSendProgress: (int sent, int total) {
          // Optional: handle progress
        },
      );

      final data = response.data;
      return UploadResult(
        fileUrl: data['fileUrl'],
        filename: data['filename'] ?? data['originalName'] ?? '',
        mimetype: data['mimetype'] ?? data['fileType'] ?? 'image/jpeg',
      );
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }
}

class UploadResult {
  final String fileUrl;
  final String filename;
  final String mimetype;

  UploadResult({
    required this.fileUrl,
    required this.filename,
    required this.mimetype,
  });
}

final uploadServiceProvider = Provider((ref) {
  return UploadService(ref.watch(dioClientProvider));
});
