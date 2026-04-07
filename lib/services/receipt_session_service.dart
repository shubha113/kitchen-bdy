import 'dart:convert';
import 'package:app/services/auth_service.dart';
import 'package:app/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/receipt_session.dart';

class ReceiptSessionService {
  static Future<Map<String, String>?> _headers() async {
    final token = await ApiService.getToken();
    if (token == null) {
      debugPrint('[ReceiptSession] No token');
      return null;
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // POST /receipt-sessions
  /// Sends OCR texts to the backend. Returns the created pending session.
  static Future<ReceiptSession?> createSession(List<String> ocrTexts) async {
    try {
      final headers = await _headers();
      if (headers == null) return null;

      final res = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/receipt-sessions'),
            headers: headers,
            body: jsonEncode({'ocrTexts': ocrTexts}),
          )
          .timeout(const Duration(seconds: 60));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return ReceiptSession.fromJson(data['session'] as Map<String, dynamic>);
      }
      debugPrint(
        '[ReceiptSession] createSession ${res.statusCode}: ${res.body}',
      );
      return null;
    } catch (e) {
      debugPrint('[ReceiptSession] createSession error: $e');
      return null;
    }
  }

  // GET /receipt-sessions
  static Future<List<ReceiptSession>> getSessions() async {
    try {
      final headers = await _headers();
      if (headers == null) return [];

      final res = await http
          .get(
            Uri.parse('${AppConstants.baseUrl}/receipt-sessions'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = data['sessions'] as List<dynamic>? ?? [];
        return list
            .map((e) => ReceiptSession.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ReceiptSession] getSessions error: $e');
      return [];
    }
  }

  // PATCH /receipt-sessions/:id/confirm
  static Future<bool> confirmSession(int sessionId) async {
    try {
      final headers = await _headers();
      if (headers == null) return false;

      final res = await http
          .patch(
            Uri.parse(
              '${AppConstants.baseUrl}/receipt-sessions/$sessionId/confirm',
            ),
            headers: headers,
            body: jsonEncode({}),
          )
          .timeout(const Duration(seconds: 15));

      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('[ReceiptSession] confirmSession error: $e');
      return false;
    }
  }

  // PATCH /receipt-sessions/:sessionId/items/:itemId
  static Future<ReceiptSessionItem?> updateItem({
    required int sessionId,
    required int itemId,
    String? itemName,
    String? category,
    String? unit,
    double? quantity,
    double? totalPrice,
  }) async {
    try {
      final headers = await _headers();
      if (headers == null) return null;

      final body = <String, dynamic>{
        if (itemName != null) 'itemName': itemName,
        if (category != null) 'category': category,
        if (unit != null) 'unit': unit,
        if (quantity != null) 'quantity': quantity,
        if (totalPrice != null) 'totalPrice': totalPrice,
      };

      final res = await http
          .patch(
            Uri.parse(
              '${AppConstants.baseUrl}/receipt-sessions/$sessionId/items/$itemId',
            ),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return ReceiptSessionItem.fromJson(
          data['item'] as Map<String, dynamic>,
        );
      }
      return null;
    } catch (e) {
      debugPrint('[ReceiptSession] updateItem error: $e');
      return null;
    }
  }

  // DELETE /receipt-sessions/:sessionId/items/:itemId
  static Future<bool> deleteItem({
    required int sessionId,
    required int itemId,
  }) async {
    try {
      final headers = await _headers();
      if (headers == null) return false;

      final res = await http
          .delete(
            Uri.parse(
              '${AppConstants.baseUrl}/receipt-sessions/$sessionId/items/$itemId',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[ReceiptSession] deleteItem error: $e');
      return false;
    }
  }
}
