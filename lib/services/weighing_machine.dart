import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kitchen_bdy/services/auth_service.dart';
import 'package:kitchen_bdy/utils/constant.dart';

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
  });

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
      );
}

// Service
class WeighingMachineService {
  // GET all machines for logged-in user
  static Future<List<WeighingMachineModel>> getUserMachines() async {
    try {
      final headers = await ApiService.authHeaders();

      final tokenPreview = headers['Authorization'] ?? 'NULL';
      debugPrint(
        '[WM] GET ${AppConstants.baseUrl}${AppConstants.getUserMachines}',
      );
      debugPrint(
        '[WM] Auth: ${tokenPreview.length > 40 ? tokenPreview.substring(0, 40) + "..." : tokenPreview}',
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
              (decoded['machines'] ??
                      decoded['data'] ??
                      decoded['weighingMachines'] ??
                      decoded['items'] ??
                      [])
                  as List<dynamic>;
        } else {
          list = [];
        }

        debugPrint('[WM] parsed ${list.length} machine(s)');
        return list
            .map(
              (e) => WeighingMachineModel.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }

      debugPrint('[WM] non-200 response — no machines returned');
      return [];
    } catch (e, st) {
      debugPrint('[WM] ERROR in getUserMachines: $e');
      debugPrint('[WM] STACK: $st');
      return [];
    }
  }

  // GET machines by ESP32 id
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

      debugPrint(
        '[WM] getMachinesByEsp($espId) → ${res.statusCode}: ${res.body}',
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List<dynamic> list = decoded is List
            ? decoded
            : ((decoded as Map)['machines'] ?? decoded['data'] ?? [])
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

  // POST bulk — register all discovered sensors in one call
  static Future<bool> registerMany(List<Map<String, dynamic>> sensors) async {
    try {
      final headers = await ApiService.authHeaders();
      debugPrint(
        '[WM] registerMany: ${sensors.length} sensor(s) → ${jsonEncode({'sensors': sensors})}',
      );
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
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('[WM] registerMany error: $e');
      return false;
    }
  }

  // POST single
  static Future<WeighingMachineModel?> registerOne({
    required String espId,
    required int slot,
    required String name,
    required String location,
    required String category,
    double threshold = 200.0,
    double capacity = 5000.0,
    String unit = 'g',
  }) async {
    try {
      final headers = await ApiService.authHeaders();
      final res = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}${AppConstants.registerMachine}'),
            headers: headers,
            body: jsonEncode({
              'espId': espId,
              'slot': slot,
              'name': name,
              'location': location,
              'category': category,
              'threshold': threshold,
              'capacity': capacity,
              'unit': unit,
            }),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('[WM] registerOne → ${res.statusCode}: ${res.body}');

      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final machineData = body['machine'] ?? body['data'] ?? body;
        return WeighingMachineModel.fromJson(
          machineData as Map<String, dynamic>,
        );
      }
      return null;
    } catch (e) {
      debugPrint('[WM] registerOne error: $e');
      return null;
    }
  }

  // PATCH
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

      debugPrint('[WM] updateMachine($sensorId) → ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[WM] updateMachine error: $e');
      return false;
    }
  }

  // DELETE
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

      debugPrint('[WM] removeMachine($sensorId) → ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[WM] removeMachine error: $e');
      return false;
    }
  }
}
