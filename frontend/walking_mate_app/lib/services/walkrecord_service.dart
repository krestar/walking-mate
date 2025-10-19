import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:walking_mate_app/services/secure_http_client.dart';
import 'package:walking_mate_app/utils/api_config.dart';

class WalkRecordService {
  final String _walkrecordUrl = '${ApiConfig.baseUrl}/walkrecord';
  final SecureHttpClient _secureHttpClient = SecureHttpClient();

  Future<Map<String, dynamic>> saveWalkRecord(
      int walkwayId, int totalTime, double totalDistance) async {
    try {
      final response = await _secureHttpClient.dio.post(
        '$_walkrecordUrl/result',
        data: {
          'walkwayId': walkwayId,
          'totalTime': totalTime,
          'totalDistance': totalDistance,
        },
      );
      return response.data;
    } catch (e) {
      if (kDebugMode) {
        print("--- 산책 기록 저장 오류 ---");
        print(e.toString());
      }
      rethrow;
    }
  }

  Future<int> getTodayWalkTime() async {
    try {
      final response = await _secureHttpClient.dio.get('$_walkrecordUrl/today');
      debugPrint("✅ [getTodayWalkTime] 서버 응답 성공: ${response.data}");
      return response.data['total_time_seconds'];
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint("❌ [getTodayWalkTime] DioException 발생 ---");
        debugPrint("요청 경로: ${e.requestOptions.path}");
        debugPrint("에러 타입: ${e.type}");
        debugPrint("서버 응답 데이터: ${e.response?.data}");
        debugPrint("------------------------------------");
      }
      return 0;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("❌ [getTodayWalkTime] 일반 Exception 발생: ${e.toString()}");
      }
      return 0;
    }
  }
}