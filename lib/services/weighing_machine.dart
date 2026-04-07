import 'dart:convert';
import 'package:app/services/auth_service.dart';
import 'package:app/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Model
class WeighingMachineModel {
  final int id;
  final String espId;
  final int slot;
  final String sensorId;
  final String name;
  final String location;
  final String category;
  final String unit;
  final double currentWeight;
  final double threshold;
  final double capacity;
  final bool isActive;
  final DateTime? lastSeen;
  final double tareWeight;
  final int? linkedInventoryId;
  final String? linkedInventoryName;
  final double? lastStableWeight;

  const WeighingMachineModel({
    required this.id,
    required this.espId,
    required this.slot,
    required this.sensorId,
    required this.name,
    required this.location,
    required this.category,
    this.unit = 'g',
    required this.currentWeight,
    this.threshold = 200.0,
    this.capacity = 5000.0,
    required this.isActive,
    this.lastSeen,
    this.tareWeight = 0,
    this.linkedInventoryId,
    this.linkedInventoryName,
    this.lastStableWeight,
  });

  double get netWeight =>
      (currentWeight - tareWeight).clamp(0.0, double.infinity);

  factory WeighingMachineModel.fromJson(Map<String, dynamic> j) =>
      WeighingMachineModel(
        id: j['id'] as int,
        espId: j['espId'] as String,
        slot: j['slot'] as int,
        sensorId: j['sensorId'] as String,
        name: j['name'] as String? ?? 'Sensor',
        location: j['location'] as String? ?? '',
        category: j['category'] as String? ?? 'Other',
        unit: j['unit'] as String? ?? 'g',
        currentWeight: (j['currentWeight'] as num?)?.toDouble() ?? 0.0,
        threshold: (j['threshold'] as num?)?.toDouble() ?? 200.0,
        capacity: (j['capacity'] as num?)?.toDouble() ?? 5000.0,
        isActive: j['isActive'] as bool? ?? true,
        lastSeen: j['lastSeen'] != null
            ? DateTime.tryParse(j['lastSeen'] as String)
            : null,
        tareWeight: (j['tareWeight'] as num?)?.toDouble() ?? 0.0,
        linkedInventoryId: j['linkedInventoryId'] as int?,
        linkedInventoryName: j['linkedInventoryName'] as String?,
        lastStableWeight: (j['lastStableWeight'] as num?)?.toDouble(),
      );
}

// Service
class WeighingMachineService {
  static Future<List<WeighingMachineModel>> getUserMachines() async {
    try {
      final headers = await ApiService.authHeaders();
      debugPrint(
        '[WM] GET ${AppConstants.baseUrl}${AppConstants.getUserMachines}',
      );

      final res = await http
          .get(
            Uri.parse('${AppConstants.baseUrl}${AppConstants.getUserMachines}'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('[WM] status = ${res.statusCode}');
      debugPrint('[WM] body   = ${res.body}');

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List<dynamic> list;
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map) {
          list =
              (decoded['machines'] ?? decoded['data'] ?? []) as List<dynamic>;
        } else {
          list = [];
        }
        return list
            .map(
              (e) => WeighingMachineModel.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }
      return [];
    } catch (e, st) {
      debugPrint('[WM] ERROR: $e\n$st');
      return [];
    }
  }

  static Future<List<WeighingMachineModel>> getMachinesByEsp(
    String espId,
  ) async {
    try {
      final headers = await ApiService.authHeaders();
      final res = await http
          .get(
            Uri.parse(
              '${AppConstants.baseUrl}${AppConstants.getMachinesByEsp(espId)}',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list =
            (decoded is Map
                    ? (decoded['machines'] ?? decoded['data'] ?? [])
                    : decoded)
                as List<dynamic>;
        return list
            .map(
              (e) => WeighingMachineModel.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[WM] getMachinesByEsp error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> registerManyWithError(
    List<Map<String, dynamic>> sensors,
  ) async {
    try {
      final headers = await ApiService.authHeaders();
      final res = await http
          .post(
            Uri.parse(
              '${AppConstants.baseUrl}${AppConstants.registerManyMachines}',
            ),
            headers: headers,
            body: jsonEncode({'sensors': sensors}),
          )
          .timeout(const Duration(seconds: 15));
      debugPrint('[WM] registerMany → ${res.statusCode}: ${res.body}');
      if (res.statusCode == 200 || res.statusCode == 201) return {'ok': true};
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return {
          'ok': false,
          'message': body['message'] ?? 'Registration failed',
        };
      } catch (_) {
        return {
          'ok': false,
          'message': 'Registration failed (${res.statusCode})',
        };
      }
    } catch (e) {
      return {'ok': false, 'message': 'Network error: $e'};
    }
  }

  static Future<bool> registerMany(List<Map<String, dynamic>> sensors) async {
    final result = await registerManyWithError(sensors);
    return result['ok'] == true;
  }

  static Future<bool> updateMachine(
    String sensorId, {
    String? name,
    String? location,
    String? category,
    double? threshold,
    double? capacity,
    String? unit,
  }) async {
    try {
      final headers = await ApiService.authHeaders();
      final body = <String, dynamic>{
        if (name != null) 'name': name,
        if (location != null) 'location': location,
        if (category != null) 'category': category,
        if (threshold != null) 'threshold': threshold,
        if (capacity != null) 'capacity': capacity,
        if (unit != null) 'unit': unit,
      };
      final res = await http
          .patch(
            Uri.parse(
              '${AppConstants.baseUrl}${AppConstants.updateMachine(sensorId)}',
            ),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[WM] updateMachine error: $e');
      return false;
    }
  }

  // Set tare weight
  // Call while empty container is on scale — pass current sensor weight.
  static Future<bool> setTare(String sensorId, double tareWeight) async {
    try {
      final headers = await ApiService.authHeaders();
      final res = await http
          .patch(
            Uri.parse(
              '${AppConstants.baseUrl}${AppConstants.setTare(sensorId)}',
            ),
            headers: headers,
            body: jsonEncode({'tareWeight': tareWeight}),
          )
          .timeout(const Duration(seconds: 10));
      debugPrint('[WM] setTare($sensorId, $tareWeight) → ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[WM] setTare error: $e');
      return false;
    }
  }

  // Link / unlink inventory item
  static Future<bool> linkInventory(String sensorId, int? inventoryId) async {
    try {
      final headers = await ApiService.authHeaders();
      final res = await http
          .patch(
            Uri.parse(
              '${AppConstants.baseUrl}${AppConstants.linkInventory(sensorId)}',
            ),
            headers: headers,
            body: jsonEncode({'inventoryId': inventoryId}),
          )
          .timeout(const Duration(seconds: 10));
      debugPrint(
        '[WM] linkInventory($sensorId, $inventoryId) → ${res.statusCode}',
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[WM] linkInventory error: $e');
      return false;
    }
  }

  static Future<bool> removeMachine(String sensorId) async {
    try {
      final headers = await ApiService.authHeaders();
      final res = await http
          .delete(
            Uri.parse(
              '${AppConstants.baseUrl}${AppConstants.deleteMachine(sensorId)}',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[WM] removeMachine error: $e');
      return false;
    }
  }
}
