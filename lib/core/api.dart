import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thrown for any failed admin API call, with a message ready to show.
class ApiException implements Exception {
  ApiException(this.message, {this.status, this.data});
  final String message;
  final int? status;
  final Map<String, dynamic>? data;
  @override
  String toString() => message;
}

/// Client for the Django admin_dashboard (`/dashboard/api/...`).
/// Auth = Bearer token from `/dashboard/api/m/auth/login/`; no cookies, no CSRF.
class AdminApi {
  AdminApi._();
  static final AdminApi I = AdminApi._();

  static const _storage = FlutterSecureStorage();
  static const _kToken = 'admin_token';
  static const _kOrigin = 'admin_origin';
  static const defaultOrigin = String.fromEnvironment(
    'ADMIN_ORIGIN',
    defaultValue: '',
  );

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 90),
      headers: {'Accept': 'application/json'},
      validateStatus: (_) => true,
    ),
  );

  String? _token;
  String origin = defaultOrigin;

  /// Called when the server rejects the token (expired / revoked).
  void Function()? onUnauthorized;

  bool get hasToken => _token != null && _token!.isNotEmpty;

  Future<void> load() async {
    _token = await _storage.read(key: _kToken);
    origin = (await _storage.read(key: _kOrigin)) ?? defaultOrigin;
  }

  Future<void> setOrigin(String value) async {
    origin = normalizeOrigin(value);
    await _storage.write(key: _kOrigin, value: origin);
  }

  static String normalizeOrigin(String value) {
    var v = value.trim();
    if (v.isEmpty) return v;
    if (!v.startsWith('http://') && !v.startsWith('https://')) v = 'https://$v';
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    if (v.endsWith('/dashboard')) {
      v = v.substring(0, v.length - '/dashboard'.length);
    }
    return v;
  }

  Future<void> setToken(String? token) async {
    _token = token;
    if (token == null) {
      await _storage.delete(key: _kToken);
    } else {
      await _storage.write(key: _kToken, value: token);
    }
  }

  String _url(String path) =>
      '$origin${path.startsWith('/') ? path : '/dashboard/api/$path'}';

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) => _send('GET', path, query: query);

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    bool form = false,
  }) => _send('POST', path, body: body, form: form);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool form = false,
  }) async {
    if (origin.isEmpty) {
      throw ApiException('Chưa cấu hình địa chỉ server admin');
    }
    final q = <String, dynamic>{};
    query?.forEach((k, v) {
      if (v != null && v.toString().isNotEmpty) q[k] = v;
    });
    Response<dynamic> res;
    try {
      res = await _dio.request(
        _url(path),
        data: body ?? (method == 'POST' && !form ? <String, dynamic>{} : null),
        queryParameters: q,
        options: Options(
          method: method,
          contentType: form
              ? Headers.formUrlEncodedContentType
              : Headers.jsonContentType,
          headers: {if (hasToken) 'Authorization': 'Bearer $_token'},
          followRedirects: false,
        ),
      );
    } on DioException catch (e) {
      throw ApiException(switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => 'Server phản hồi quá lâu, thử lại sau',
        DioExceptionType.connectionError =>
          'Không kết nối được server ($origin)',
        _ => e.message ?? 'Lỗi mạng',
      });
    }
    final status = res.statusCode ?? 0;
    final data = res.data;
    final Map<String, dynamic> map;
    if (data is Map) {
      map = Map<String, dynamic>.from(data);
    } else {
      map = {
        'success': false,
        'error': status >= 300 && status < 400
            ? 'Phiên đăng nhập không hợp lệ (bị chuyển hướng)'
            : 'Phản hồi không hợp lệ từ server (HTTP $status)',
      };
    }
    if (status == 401 && hasToken) onUnauthorized?.call();
    final failed =
        status >= 300 || map['success'] == false || map['ok'] == false;
    if (failed) {
      throw ApiException(
        (map['error'] ?? map['message'] ?? 'Lỗi HTTP $status').toString(),
        status: status,
        data: map,
      );
    }
    return map;
  }
}
