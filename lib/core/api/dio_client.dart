import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';
import 'interceptors/auth_interceptor.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

Dio buildDio({required AuthInterceptor authInterceptor}) {
  final dio = Dio(
    BaseOptions(
      baseUrl:        AppConstants.apiUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers:        {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(authInterceptor);

  // Em debug, ignora certificado autoassinado do servidor local.
  assert(() {
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (_, __, ___) => true;
      return client;
    };
    return true;
  }());

  // Log only in debug builds.
  assert(() {
    dio.interceptors.add(
      LogInterceptor(
        requestBody:  true,
        responseBody: true,
        error:        true,
        logPrint:     (obj) => _log.d(obj),
      ),
    );
    return true;
  }());

  return dio;
}
