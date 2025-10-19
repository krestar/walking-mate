import 'package:dio/dio.dart';
import 'package:walking_mate_app/services/secure_http_client.dart';
import 'package:walking_mate_app/utils/api_config.dart';

class CharacterService {
  final String _characterUrl = '${ApiConfig.baseUrl}/character';
  final Dio _dio = SecureHttpClient().dio;

  Future<Map<String, dynamic>> getInventory() async {
    final response = await _dio.get('$_characterUrl/inventory');
    return response.data;
  }

  Future<void> buyCharacter(String characterId) async {
    await _dio.post('$_characterUrl/buy/$characterId');
  }

  Future<void> equipItems(Map<String, int?> items, String characterType) async {
    await _dio.post(
      '$_characterUrl/equip',
      data: {
        'items': items,
        'characterType': characterType,
      },
    );
  }
}
