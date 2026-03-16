import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kitchen_bdy/services/auth_service.dart';
import 'package:kitchen_bdy/utils/constant.dart';
import '../models/manual_inventory_item.dart';

class ManualInventoryService {
  static Future<Map<String, String>?> _headers() async {
    final token = await ApiService.getToken();
    if (token == null) {
      debugPrint('[ManualInventory] No token');
      return null;
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // POST /manual-inventory/parse-receipt
  static Future<int> parseReceipt(String ocrText) async {
    try {
      final headers = await _headers();
      if (headers == null) return -1;

      debugPrint(
        '[ManualInventory] parseReceipt: sending ${ocrText.length} chars of OCR text',
      );

      final res = await http.post(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.parseReceipt}'),
        headers: headers,
        body: jsonEncode({'ocrText': ocrText}),
      );

      debugPrint(
        '[ManualInventory] parseReceipt → ${res.statusCode}: ${res.body}',
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['count'] as int?) ?? 0;
      }
      return -1;
    } catch (e) {
      debugPrint('[ManualInventory] parseReceipt error: $e');
      return -1;
    }
  }

  // POST /manual-inventory
  static Future<ManualInventoryItem?> addPurchase({
    required String itemName,
    required String category,
    required double quantity,
    required String unit,
    double? packsCount,
    double? packSizeGrams,
    double? pricePerUnit,
    double? threshold,
    String? linkedSensorId,
  }) async {
    try {
      final headers = await _headers();
      if (headers == null) return null;

      final body = <String, dynamic>{
        'itemName': itemName,
        'category': category,
        'quantity': quantity,
        'unit': unit,
        if (packsCount != null) 'packsCount': packsCount,
        if (packSizeGrams != null) 'packSizeGrams': packSizeGrams,
        if (pricePerUnit != null) 'pricePerUnit': pricePerUnit,
        if (threshold != null) 'threshold': threshold,
        if (linkedSensorId != null) 'linkedSensorId': linkedSensorId,
      };

      final res = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}${AppConstants.manualInventory}'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return ManualInventoryItem.fromJson(
          data['item'] as Map<String, dynamic>,
        );
      }
      return null;
    } catch (e) {
      debugPrint('[ManualInventory] addPurchase error: $e');
      return null;
    }
  }

  // GET /manual-inventory
  static Future<List<ManualInventoryItem>> getUserInventory() async {
    try {
      final headers = await _headers();
      if (headers == null) return [];

      final res = await http
          .get(
            Uri.parse('${AppConstants.baseUrl}${AppConstants.manualInventory}'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];
        return items
            .map((j) => ManualInventoryItem.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ManualInventory] getUserInventory error: $e');
      return [];
    }
  }

  // PATCH /manual-inventory/:id/remaining
  static Future<bool> updateRemaining(int id, double packsRemaining) async {
    try {
      final headers = await _headers();
      if (headers == null) return false;

      final res = await http
          .patch(
            Uri.parse(
              '${AppConstants.baseUrl}${AppConstants.manualInventoryRemaining(id)}',
            ),
            headers: headers,
            body: jsonEncode({'packsRemaining': packsRemaining}),
          )
          .timeout(const Duration(seconds: 10));

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[ManualInventory] updateRemaining error: $e');
      return false;
    }
  }

  // PATCH /manual-inventory/:id/threshold
  static Future<bool> updateThreshold(int id, double? threshold) async {
    try {
      final headers = await _headers();
      if (headers == null) return false;

      final res = await http
          .patch(
            Uri.parse(
              '${AppConstants.baseUrl}${AppConstants.manualInventoryThreshold(id)}',
            ),
            headers: headers,
            body: jsonEncode({'threshold': threshold}),
          )
          .timeout(const Duration(seconds: 10));

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[ManualInventory] updateThreshold error: $e');
      return false;
    }
  }

  // PATCH /manual-inventory/:id/price
  static Future<bool> updatePrice(int id, double pricePerUnit) async {
    try {
      final headers = await _headers();
      if (headers == null) return false;

      final res = await http
          .patch(
            Uri.parse(
              '${AppConstants.baseUrl}${AppConstants.manualInventoryPrice(id)}',
            ),
            headers: headers,
            body: jsonEncode({'pricePerUnit': pricePerUnit}),
          )
          .timeout(const Duration(seconds: 10));

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[ManualInventory] updatePrice error: $e');
      return false;
    }
  }

  // PATCH /manual-inventory/:id/sensor─
  static Future<bool> linkSensor(int id, String? sensorId) async {
    try {
      final headers = await _headers();
      if (headers == null) return false;

      final res = await http
          .patch(
            Uri.parse(
              '${AppConstants.baseUrl}${AppConstants.manualInventorySensor(id)}',
            ),
            headers: headers,
            body: jsonEncode({'sensorId': sensorId}),
          )
          .timeout(const Duration(seconds: 10));

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[ManualInventory] linkSensor error: $e');
      return false;
    }
  }

  // DELETE /manual-inventory/:id
  static Future<bool> delete(int id) async {
    try {
      final headers = await _headers();
      if (headers == null) return false;

      final res = await http
          .delete(
            Uri.parse(
              '${AppConstants.baseUrl}${AppConstants.manualInventoryDelete(id)}',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[ManualInventory] delete error: $e');
      return false;
    }
  }
}
