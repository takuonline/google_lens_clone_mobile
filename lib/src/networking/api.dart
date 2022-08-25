import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class ApiService {
  final logger = Logger();
  final numRetries = 1;
  // final baseUrl = "http://10.0.2.2:8000";
  // final baseUrl = "https://google.com/";
  // final baseUrl = "http://34.241.37.140:8000";
  final Map<String, String> _headers = {
    'Content-Type': 'application/json;charset=UTF-8',
    'Charset': 'utf-8',
    'Connection': "Keep-Alive",
    "Keep-Alive": "timeout=5, max=100"
  };

  final dioOptions = BaseOptions(
      baseUrl: "http://10.0.2.2:8000",
      // baseUrl: "http://54.170.227.68:8000",
      connectTimeout: 15000,
      receiveTimeout: 15000,
      headers: {
        'Content-Type': 'application/json;charset=UTF-8',
        'Charset': 'utf-8',
        'Connection': "keep-alive",
      });

  Future<void> getHealthCheck() async {
    logger.i("Checking health dio");
    Response response;
    Dio dio = Dio(dioOptions);
    response = await dio.get('/');
    logger.d(response.statusCode);
    logger.d(response.data.toString());
  }

  Future<Map<String, dynamic>?> postImage(
      String imgData, bool isUserFineTuned) async {
    Map<String, dynamic> data;

    Response response;
    Dio dio = Dio(dioOptions);
    final String endpoint = isUserFineTuned ? '/search' : '/detect';
    data = {"img_data": imgData, "num_of_results": 20};

    for (int i = 0; i < numRetries; i++) {
      try {
        response = await dio.post(endpoint, data: data);
        logger.d(response.statusCode);
        String statusCode =
            response.statusCode != null ? response.statusCode.toString() : "";

        if (statusCode.startsWith("2")) {
          logger.d(response.data);
          return response.data;
        } else {
          return null;
        }
      } on HttpException {
        logger.w("HttpException");
        continue;
      } catch (e) {
        logger.e(e);
      }
    }
    return null;
  }
}
