import 'package:dio/dio.dart';
import 'package:walking_mate_app/models/friend_model.dart';
import 'package:walking_mate_app/services/secure_http_client.dart';
import 'package:walking_mate_app/utils/api_config.dart';

class FriendService {
  final String _friendUrl = '${ApiConfig.baseUrl}/friends';
  final Dio _dio = SecureHttpClient().dio;

  Future<List<Friend>> getFriends() async {
    final response = await _dio.get(_friendUrl);
    final List<dynamic> data = response.data;
    return data.map((json) => Friend.fromJson(json)).toList();
  }

  Future<Map<String, List<Friend>>> getAllRequests() async {
    final response = await _dio.get('$_friendUrl/requests/all');
    final data = response.data;
    final List<Friend> received = (data['received'] as List)
        .map((json) => Friend.fromJson(json))
        .toList();
    final List<Friend> sent =
        (data['sent'] as List).map((json) => Friend.fromJson(json)).toList();
    return {'received': received, 'sent': sent};
  }

  Future<void> sendFriendRequest(int userId) async {
    await _dio.post(
      '$_friendUrl/request',
      data: {'receiverId': userId},
    );
  }

  Future<void> acceptFriendRequest(int friendshipId) async {
    await _dio.post(
      '$_friendUrl/accept',
      data: {'friendshipId': friendshipId},
    );
  }

  Future<void> rejectOrCancelRequest(int friendshipId) async {
    await _dio.delete('$_friendUrl/request/$friendshipId');
  }

  Future<void> deleteFriend(int friendshipId) async {
    await _dio.delete('$_friendUrl/$friendshipId');
  }
}

