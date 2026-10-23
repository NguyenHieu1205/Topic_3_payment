import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/order_payment.dart';

class PaymentService {
  static String baseUrl = kIsWeb ? 'http://localhost:3000' : 'http://10.0.2.2:3000';

  // Method to create a new order
  Future<OrderPayment> createOrder(double amount) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/orders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'amount': amount}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return OrderPayment.fromJson(data);
      } else {
        throw Exception('Mã lỗi từ server: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Yêu cầu kết nối quá hạn (Timeout). Vui lòng thử lại.');
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('Network') || e.toString().contains('XMLHttpRequest')) {
        throw Exception('Không thể kết nối đến máy chủ. Vui lòng kiểm tra địa chỉ API hoặc kết nối internet.');
      }
      throw Exception('Lỗi hệ thống: $e');
    }
  }

  // Method to get status of an order
  Future<OrderPayment> getOrder(String orderCode) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/orders/$orderCode'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return OrderPayment.fromJson(data);
      } else {
        throw Exception('Không tìm thấy đơn hàng trên hệ thống (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Yêu cầu kiểm tra đơn hàng bị quá hạn.');
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('Network') || e.toString().contains('XMLHttpRequest')) {
        throw Exception('Mất kết nối máy chủ. Kiểm tra URL API hoặc mạng.');
      }
      throw Exception('Lỗi tải đơn hàng: $e');
    }
  }
}
