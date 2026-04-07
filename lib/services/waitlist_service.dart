import 'dart:convert';
import 'package:app/services/auth_service.dart';
import 'package:app/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WaitlistService {
  static Future<Map<String, dynamic>> join() async {
    try {
      final headers = await ApiService.authHeaders();
      final res = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}${AppConstants.waitlistJoin}'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint('[Waitlist] join error: $e');
      return {'success': false, 'message': 'Something went wrong'};
    }
  }

  static Future<bool> isOnWaitlist() async {
    try {
      final headers = await ApiService.authHeaders();
      final res = await http
          .get(
            Uri.parse('${AppConstants.baseUrl}${AppConstants.waitlistStatus}'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['onWaitlist'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }
}
