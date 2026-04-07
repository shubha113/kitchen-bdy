import 'dart:convert';
import 'dart:io';
import 'package:app/utils/constant.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

class ApiService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  // Register API call
  static Future<Map<String, dynamic>> register(
    String email,
    String password,
  ) async {
    try {
      final url = Uri.parse(
        '${AppConstants.baseUrl}${AppConstants.registerEndpoint}',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        // Save token
        if (data['token'] != null) {
          await _saveToken(data['token']);
        }

        return {'success': true, 'token': data['token'], 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Login API call
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final url = Uri.parse(
        '${AppConstants.baseUrl}${AppConstants.loginEndpoint}',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        final email = data['email'] ?? data['user']?['email'] ?? 'User';

        if (data['token'] != null) {
          await _saveToken(data['token']);
        }

        //Save User
        if (data['token'] != null) {
          await _saveUser(data['token'], email);
        }

        return {'success': true, 'token': data['token'], 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Google Sign-In — returns idToken to send to your backend
  static Future<Map<String, dynamic>> loginWithGoogle() async {
    try {
      // Trigger the Google sign-in flow
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        return {'success': false, 'message': 'Google sign-in cancelled'};
      }

      final GoogleSignInAuthentication googleAuth =
          await account.authentication;

      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        return {'success': false, 'message': 'Failed to get Google ID token'};
      }

      debugPrint('[Google] idToken: $idToken');
      debugPrint('[Google] accessToken: ${googleAuth.accessToken}');
      // Send idToken to backend
      final url = Uri.parse(
        '${AppConstants.baseUrl}${AppConstants.googleAuthEndpoint}',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        final email = data['email'] ?? data['user']?['email'] ?? account.email;

        if (data['token'] != null) {
          await _saveToken(data['token']);
          await _saveUser(data['token'], email);
        }

        return {'success': true, 'token': data['token'], 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Google login failed',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Google sign-in error: $e'};
    }
  }

  /// Sign out from Google as well on logout
  static Future<void> googleSignOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  //Get Profile
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = await getToken();

      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final url = Uri.parse(
        '${AppConstants.baseUrl}${AppConstants.profileEndpoint}',
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to load profile'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Registers or refreshes the device FCM token with the backend.
  /// Call this after login AND whenever Firebase rotates the token.
  static Future<void> registerFcmToken(String token) async {
    try {
      final headers = await authHeaders();
      final url = Uri.parse('${AppConstants.baseUrl}/auth/fcm-token');

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'token': token,
          'deviceType': Platform.isIOS ? 'ios' : 'android',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[FCM] Token registered with backend ✓');
      } else {
        debugPrint('[FCM] Token registration failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[FCM] Token registration error: $e');
    }
  }

  /// Removes the FCM token on logout so no notifications go to signed-out devices.
  static Future<void> unregisterFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      final headers = await authHeaders();
      final url = Uri.parse('${AppConstants.baseUrl}/auth/fcm-token');
      await http.delete(
        url,
        headers: headers,
        body: jsonEncode({'token': token}),
      );
      debugPrint('[FCM] Token unregistered ✓');
    } catch (e) {
      debugPrint('[FCM] Token unregister error: $e');
    }
  }

  // Save token to local storage
  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  // Get saved token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // Clear token
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  //Save user
  static Future<void> _saveUser(String token, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    await prefs.setString('user_email', email);
  }

  // Create authenticated headers
  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
