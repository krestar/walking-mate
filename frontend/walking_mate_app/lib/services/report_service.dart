import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:walking_mate_app/services/secure_http_client.dart';
import 'package:walking_mate_app/utils/api_config.dart';

class ReportService {
  final String _reportUrl = '${ApiConfig.baseUrl}/report';
  final Dio _dio = SecureHttpClient().dio;

  Future<void> submitReport({
    required String targetType,
    required String targetId,
    required String reason,
    required Uint8List screenshotBytes,
  }) async {
    FormData formData = FormData.fromMap({
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      'screenshot': MultipartFile.fromBytes(
        screenshotBytes,
        filename: 'report-screenshot.png',
      ),
    });

    await _dio.post(_reportUrl, data: formData);
  }
}