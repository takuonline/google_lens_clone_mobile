import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;

class ApiService extends ChangeNotifier {
  final logger = Logger();
  final baseUrl = "http://10.0.2.2:5000";

  Map<String, String> _headers = {
    'Content-Type': 'application/json;charset=UTF-8',
    'Charset': 'utf-8',
    'Connection' :"keep-alive",
    'Content-Type': 'application/json;charset=UTF-8',
    'Charset': 'utf-8'
  };


  // final baseUrl = "http://192.168.1.109:5000";
  // final baseUrl = "http://www.google.com";

  // Dio dio = Dio();
  // final DioOptions = BaseOptions(
  //
  //     // baseUrl: 'http://192.168.1.109:5000/',
  //     baseUrl: 'http://10.0.2.2',
  //
  //     connectTimeout: 5000,
  //     receiveTimeout: 3000,
  //   );

  Future<void> getHealthCheck() async {
    logger.i("Checking health dio");
    Response response;
    Dio dio = Dio();
    response = await dio.get(baseUrl + '/');
    logger.d(response.statusCode);
    logger.d(response.data.toString());
  }

  Future<Map<String, dynamic>?> postImage(String img_data) async {
    Response response;
    Dio dio = Dio();
    Map<String, dynamic> data = {"img_data": img_data,"num_of_results": 20};
    response = await dio.post(baseUrl + '/detect', data: data, options: Options(headers:_headers));
    logger.d(response.statusCode);
    String statusCode =
        response.statusCode != null ? response.statusCode.toString() : "";

    if (statusCode.startsWith("2")) {
      logger.d(response.data.runtimeType);
      return response.data;
    } else {
      return null;
    }
  }
}
