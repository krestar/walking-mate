import 'package:dio/dio.dart';
import 'package:walking_mate_app/models/community_model.dart';
import 'package:walking_mate_app/services/secure_http_client.dart';
import 'package:walking_mate_app/utils/api_config.dart';

class CommunityService {
  final String _communityUrl = '${ApiConfig.baseUrl}/community';
  final Dio _dio = SecureHttpClient().dio;

  Future<List<Crew>> getMyCrews() async {
    final response = await _dio.get('$_communityUrl/crews/my');
    final List<dynamic> data = response.data;
    return data.map((json) => Crew.fromJson(json)).toList();
  }

  Future<void> createCrew(String name, String description) async {
    await _dio.post(
      '$_communityUrl/crews',
      data: {
        'crew_name': name,
        'description': description,
      },
    );
  }

  Future<void> deleteCrew(int crewId) async {
    await _dio.delete('$_communityUrl/crews/$crewId');
  }

  Future<void> leaveCrew(int crewId) async {
    await _dio.delete('$_communityUrl/crews/$crewId/leave');
  }

  Future<List<CrewMember>> getCrewMembers(int crewId) async {
    final response = await _dio.get('$_communityUrl/crews/$crewId/members');
    final List<dynamic> data = response.data;
    return data.map((json) => CrewMember.fromJson(json)).toList();
  }

  Future<void> removeCrewMember(int crewId, int memberId) async {
    await _dio.delete('$_communityUrl/crews/$crewId/members/$memberId');
  }

  Future<List<Post>> getPosts(int crewId) async {
    final response = await _dio.get('$_communityUrl/crews/$crewId/posts');
    final List<dynamic> data = response.data;
    return data.map((json) => Post.fromJson(json)).toList();
  }

  Future<void> createPost(int crewId, String title, String content) async {
    await _dio.post(
      '$_communityUrl/crews/$crewId/posts',
      data: {
        'title': title,
        'content': content,
      },
    );
  }

  Future<void> updatePost(int postId, String title, String content) async {
    await _dio.put(
      '$_communityUrl/posts/$postId',
      data: {
        'title': title,
        'content': content,
      },
    );
  }

  Future<void> deletePost(int postId) async {
    await _dio.delete('$_communityUrl/posts/$postId');
  }

  Future<List<UserSearchResult>> searchUsers(String term, {String? location}) async {
    final queryParams = {
      'term': term,
      if (location != null) 'location': location,
    };
    final response = await _dio.get('$_communityUrl/search/users', queryParameters: queryParams);
    final List<dynamic> data = response.data;
    return data.map((json) => UserSearchResult.fromJson(json)).toList();
  }

  Future<List<CrewSearchResult>> searchCrews(String term) async {
    final response = await _dio.get('$_communityUrl/search/crews?term=${Uri.encodeComponent(term)}');
    final List<dynamic> data = response.data;
    return data.map((json) => CrewSearchResult.fromJson(json)).toList();
  }

  Future<void> joinCrew(int crewId) async {
    await _dio.post('$_communityUrl/crews/$crewId/join');
  }
}