import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:walking_mate_app/models/community_model.dart';
import 'package:walking_mate_app/models/walkway_model.dart';
import 'package:walking_mate_app/services/secure_http_client.dart';
import 'package:walking_mate_app/utils/api_config.dart';

class WalkwayService {
  final String _walkwayUrl = '${ApiConfig.baseUrl}/walkways';
  final String _locationUrl = '${ApiConfig.baseUrl}/locations';
  final Dio _dio = SecureHttpClient().dio;

  Future<void> likeWalkway(int walkwayId) async {
    await _dio.post('$_walkwayUrl/$walkwayId/like');
  }

  Future<void> unlikeWalkway(int walkwayId) async {
    await _dio.delete('$_walkwayUrl/$walkwayId/like');
  }

  Future<void> uploadThumbnail(int walkwayId, Uint8List imageBytes) async {
    try {
      FormData formData = FormData.fromMap({
        'thumbnail': MultipartFile.fromBytes(
          imageBytes,
          filename: 'walkway-$walkwayId.png',
        ),
      });
      await _dio.post(
        '$_walkwayUrl/$walkwayId/thumbnail',
        data: formData,
      );
    } on DioException catch (e) {
      if (kDebugMode) {
        print("--- ERROR in uploadThumbnail ---");
        print(e.toString());
      }
      rethrow;
    }
  }

  Future<String> getAddressFromCoords(NLatLng coords) async {
    try {
      final response = await _dio.post(
        '$_locationUrl/address',
        data: {
          'lat': coords.latitude,
          'lng': coords.longitude,
        },
      );
      return response.data['address'];
    } on DioException catch (e) {
      if (kDebugMode) {
        print("--- ERROR in getAddressFromCoords ---");
        print(e.toString());
      }
      rethrow;
    }
  }

  Future<List<Walkway>> getWalkways() async {
    try {
      final response = await _dio.get(_walkwayUrl);
      final List<dynamic> walkwaysJson = response.data;
      return walkwaysJson.map((json) => Walkway.fromJson(json)).toList();
    } on DioException catch (e, s) {
      if (kDebugMode) {
        print("--- ERROR in getWalkways ---");
        print(s.toString());
      }
      rethrow;
    }
  }

  Future<Walkway> getWalkwayById(int id) async {
    final response = await _dio.get('$_walkwayUrl/$id');
    return Walkway.fromJson(response.data);
  }

  Future<Map<String, dynamic>> createWalkway(
      Map<String, dynamic> walkwayData) async {
    final response = await _dio.post(
      '$_walkwayUrl/recommend',
      data: walkwayData,
      options: Options(
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    return response.data;
  }

  Future<List<Comment>> getComments(int walkwayId) async {
    final response = await _dio.get('$_walkwayUrl/$walkwayId/comments');
    final List<dynamic> commentsJson = response.data;
    return commentsJson.map((json) => Comment.fromJson(json)).toList();
  }

  Future<void> createComment(int walkwayId, String content) async {
    await _dio.post(
      '$_walkwayUrl/$walkwayId/comments',
      data: {'content': content},
    );
  }

  Future<void> updateWalkway(
      int walkwayId, String title, String description, String status) async {
    await _dio.put(
      '$_walkwayUrl/$walkwayId',
      data: {
        'title': title,
        'description': description,
        'status': status,
      },
    );
  }

  Future<void> deleteWalkway(int walkwayId) async {
    await _dio.delete('$_walkwayUrl/$walkwayId');
  }

  Future<void> deleteComment(int walkwayId, int commentId) async {
    await _dio.delete('$_walkwayUrl/$walkwayId/comments/$commentId');
  }
}