import 'package:dio/dio.dart';
import 'package:walking_mate_app/models/item_model.dart';
import 'package:walking_mate_app/services/secure_http_client.dart';
import 'package:walking_mate_app/utils/api_config.dart';

class ShopService {
  final String _shopUrl = '${ApiConfig.baseUrl}/shop';
  final Dio _dio = SecureHttpClient().dio;

  Future<List<Item>> getItems() async {
    final response = await _dio.get('$_shopUrl/items');
    final List<dynamic> data = response.data;
    return data.map((json) => Item.fromJson(json)).toList();
  }

  Future<void> buyItem(int itemId) async {
    await _dio.post('$_shopUrl/items/$itemId/buy');
  }
}