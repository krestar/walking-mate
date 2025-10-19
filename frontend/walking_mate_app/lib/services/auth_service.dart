import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:walking_mate_app/services/secure_http_client.dart';
import 'package:walking_mate_app/utils/api_config.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final String _authUrl = '${ApiConfig.baseUrl}/auth';
  final String _userUrl = '${ApiConfig.baseUrl}/user';
  final _storage = const FlutterSecureStorage();
  final Dio _dio = SecureHttpClient().dio;

  Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_authUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _storage.write(key: 'access_token', value: data['accessToken']);
      await _storage.write(key: 'refresh_token', value: data['refreshToken']);

      final firebaseToken = data['firebaseCustomToken'];
      if (firebaseToken != null && firebaseToken.isNotEmpty) {
        try {
          await FirebaseAuth.instance.signInWithCustomToken(firebaseToken);
        } on FirebaseAuthException catch (e) {
          debugPrint("--- Firebase Auth Exception ---");
          debugPrint("Code: ${e.code}");
          debugPrint("Message: ${e.message}");
          debugPrint("-----------------------------");
          throw Exception('Firebase 인증에 실패했습니다: ${e.code}');
        }
      } else {
        throw Exception('서버로부터 Firebase 인증 토큰을 받지 못했습니다.');
      }
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? '로그인에 실패했습니다.');
    }
  }

  Future<Map<String, dynamic>> getFullUserProfile() async {
    final response = await _dio.get('$_userUrl/profile');
    return response.data;
  }

  Future<void> updateUserProfile(Map<String, dynamic> userData) async {
    await _dio.put(
      '$_userUrl/profile',
      data: userData,
    );
  }

  Future<Map<String, dynamic>> uploadProfileImage(File imageFile) async {
    String fileName = imageFile.path.split('/').last;
    FormData formData = FormData.fromMap({
      "profileImage": await MultipartFile.fromFile(imageFile.path, filename: fileName),
    });
    final response = await _dio.post(
      '$_userUrl/profile-image',
      data: formData,
    );
    return response.data;
  }

  Future<void> register(String email, String password, String nickname) async {
    final response = await http.post(
      Uri.parse('$_authUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
          {'email': email, 'password': password, 'nickname': nickname}),
    );

    if (response.statusCode != 201) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? '회원가입에 실패했습니다.');
    }
  }

  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    await _dio.post(
      '$_userUrl/password',
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    await _storage.deleteAll();
  }

  Future<bool> isLoggedIn() async {
    String? token = await _storage.read(key: 'access_token');
    return token != null;
  }
}

