import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class ApiService extends ChangeNotifier {
  final logger = Logger();
  final baseUrl = "http://18.203.156.46:8000";
  // final baseUrl = "http://1.1.1.1";

  // final baseUrl = "http://52.214.24.119:8000/";

  // final baseUrl = "http://34.241.42.157:8000/";
  // final baseUrl = "http://192.168.1.109:5000";
  // final baseUrl = "http://52.50.63.28:5000/";
  // final baseUrl = "https://google.com/";
  final Map<String, String> _headers = {
    'Content-Type': 'application/json;charset=UTF-8',
    'Charset': 'utf-8',
    'Connection': "keep-alive",
  };

  // Dio dio = Dio();
  // final DioOptions = BaseOptions(
  //     // baseUrl: 'http://192.168.1.109:5000/',
  //     baseUrl: 'http://10.0.2.2',

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

  Future<Map<String, dynamic>?> postImage(String imgData) async {
    Response response;
    Dio dio = Dio();
    Map<String, dynamic> data = {"img_data": imgData, "num_of_results": 10};
    response = await dio.post(baseUrl + '/detect',
        data: data, options: Options(headers: _headers));
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
