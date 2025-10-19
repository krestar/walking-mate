import 'package:walking_mate_app/services/secure_http_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class AchievementService {
  final SecureHttpClient _secureHttpClient = SecureHttpClient();
  final String _achievementUrl = '/achievements';

  Future<Map<String, dynamic>> getAchievements() async {
    try {
      final response = await _secureHttpClient.dio.get(_achievementUrl);
      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        print("--- ERROR in getAchievements ---");
        print(e.response?.data ?? e.message);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> claimReward(int achievementId) async {
    try {
      final response = await _secureHttpClient.dio.post(
        '$_achievementUrl/$achievementId/claim',
        data: {},
      );
      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        print("--- ERROR in claimReward ---");
        print(e.response?.data ?? e.message);
      }
      rethrow;
    }
  }
}

