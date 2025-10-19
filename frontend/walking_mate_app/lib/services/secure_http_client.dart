import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:walking_mate_app/utils/api_config.dart';

class SecureHttpClient {
  static final SecureHttpClient _instance = SecureHttpClient._internal();
  late Dio dio;

  factory SecureHttpClient() {
    return _instance;
  }

  SecureHttpClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15), // 3초 -> 15초로 변경
    ));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          const storage = FlutterSecureStorage();
          final accessToken = await storage.read(key: 'access_token');
          if (accessToken != null) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            const storage = FlutterSecureStorage();
            final refreshToken = await storage.read(key: 'refresh_token');

            if (refreshToken != null) {
              try {
                final refreshResponse = await Dio().post(
                  '${ApiConfig.baseUrl}/auth/refresh',
                  data: {'refreshToken': refreshToken},
                );

                if (refreshResponse.statusCode == 200) {
                  final newAccessToken = refreshResponse.data['accessToken'];
                  final newRefreshToken = refreshResponse.data['refreshToken'];

                  await storage.write(key: 'access_token', value: newAccessToken);
                  await storage.write(key: 'refresh_token', value: newRefreshToken);
                  
                  e.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
                  
                  final clonedRequest = await dio.request(
                    e.requestOptions.path,
                    options: Options(
                      method: e.requestOptions.method,
                      headers: e.requestOptions.headers,
                    ),
                    data: e.requestOptions.data,
                    queryParameters: e.requestOptions.queryParameters,
                  );
                  
                  return handler.resolve(clonedRequest);
                }
              } catch (refreshError) {
                 // 리프레시 실패 시 로그아웃 처리
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
  }
}