import 'dart:async';
import 'dart:convert';
import 'package:app/services/weighing_machine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/device.dart';
import '../models/recipe.dart';
import '../models/alert.dart';
import '../models/grocery_item.dart';
import '../data/mock_data.dart';
import '../services/ble_service.dart';
import '../services/fcm_service.dart';

const String _mqttBroker = '103.211.202.131';
const int _mqttPort = 1883;
const String _mqttUser = 'root';
const String _mqttPassword = 'AcceptIt@123';

class AppProvider extends ChangeNotifier {
  List<KitchenDevice> _devices = [];
  List<Recipe> _recipes = [];
  List<AppAlert> _systemAlerts = [];
  List<AppAlert> _customAlerts = [];
  List<GroceryItem> _groceryItems = [];

  List<KitchenDevice> get devices => _devices;
  List<Recipe> get recipes => _recipes;
  List<AppAlert> get alerts {
    final all = [..._customAlerts, ..._systemAlerts];
    all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all;
  }

  List<GroceryItem> get groceryItems => _groceryItems;
  int get unreadAlertCount => alerts.where((a) => !a.isRead).length;

  bool _loadingDevices = false;
  bool get loadingDevices => _loadingDevices;

  final BleService _ble = BleService();
  BleService get bleService => _ble;

  bool _isScanning = false;
  bool get isScanning => _isScanning;
  List<Map<String, String>> _scannedDevices = [];
  List<Map<String, String>> get scannedDevices => _scannedDevices;

  String _bleStatus = '';
  String get bleStatus => _bleStatus;

  List<int> _discoveredSlots = [];
  List<int> get discoveredSlots => _discoveredSlots;
  String _connectedEspId = '';
  String get connectedEspId => _connectedEspId;

  StreamSubscription? _bleScanSub;
  StreamSubscription? _bleStatusSub;
  StreamSubscription? _bleDiscoverySub;

  MqttServerClient? _mqttClient;
  bool _mqttConnected = false;
  bool get mqttConnected => _mqttConnected;

  // Tracks last MQTT message time per sensorId.
  final Map<String, DateTime> _lastMqttTime = {};
  Timer? _offlineCheckTimer;

  double get pantryHealthScore {
    if (_devices.isEmpty) return 0.0;
    final healthy = _devices.where((d) => d.isOnline && !d.isLowStock).length;
    return healthy / _devices.length;
  }

  Map<String, double> get inventoryMap {
    final map = <String, double>{};
    for (final d in _devices) {
      if (d.isOnline) map[d.name.toLowerCase()] = d.currentWeight;
    }
    return map;
  }

  int get onlineDevicesCount => _devices.where((d) => d.isOnline).length;
  int get lowStockCount => _devices.where((d) => d.isLowStock).length;
  int get availableRecipeCount =>
      _recipes.where((r) => r.canMake(inventoryMap)).length;

  /// Unique list of ESP32 ids from registered sensors
  List<String> get espIds {
    final seen = <String>{};
    return _devices
        .map((d) => d.espId ?? '')
        .where((id) => id.isNotEmpty && seen.add(id))
        .toList();
  }

  /// All sensors belonging to a specific ESP32
  List<KitchenDevice> devicesForEsp(String espId) =>
      _devices.where((d) => d.espId == espId).toList()
        ..sort((a, b) => (a.slot ?? 0).compareTo(b.slot ?? 0));

  List<KitchenDevice> devicesForEspDisplay(String espId) =>
      devicesForEsp(espId).map((d) => d.copyWith(isOnline: true)).toList();

  AppProvider() {
    _listenBleStatus();
    _init();
  }

  Future<void> _init() async {
    await _loadDevicesFromApi();
    await _connectMqtt();
    _startOfflineTimer();
    await _initFcm();
  }

  void clearDevices() {
    _devices = [];
    _lastMqttTime.clear();
    _refreshAlerts();
    notifyListeners();
  }

  Future<void> _initFcm() async {
    await FcmService.instance.init(
      onAlert: (alert) {
        addAlert(alert);

        // If a sensor just came back online, also flip its isOnline flag in UI
        if (alert.type == AlertType.deviceOnline && alert.deviceId != null) {
          final idx = _devices.indexWhere((d) => d.id == alert.deviceId);
          if (idx != -1) {
            _devices[idx] = _devices[idx].copyWith(isOnline: true);
            notifyListeners();
          }
        }

        // If a sensor went offline, also flip its isOnline flag in UI
        if (alert.type == AlertType.deviceOffline && alert.deviceId != null) {
          final idx = _devices.indexWhere((d) => d.id == alert.deviceId);
          if (idx != -1) {
            _devices[idx] = _devices[idx].copyWith(isOnline: false);
            _refreshAlerts();
            notifyListeners();
          }
        }
      },
    );
  }

  // LOAD DEVICES FROM API
  Future<void> _loadDevicesFromApi() async {
    _loadingDevices = true;
    notifyListeners();

    try {
      final machines = await WeighingMachineService.getUserMachines();

      debugPrint('[API] returned ${machines.length} machine(s)');
      for (final m in machines) {
        debugPrint(
          '[API]   sensorId=${m.sensorId}  name=${m.name}  espId=${m.espId}  slot=${m.slot}',
        );
      }

      if (machines.isNotEmpty) {
        _devices = machines
            .map(
              (m) => KitchenDevice(
                id: m.sensorId,
                espId: m.espId,
                slot: m.slot,
                name: m.name,
                location: m.location,
                category: m.category,
                unit: m.unit,
                currentWeight: m.currentWeight,
                threshold: m.threshold,
                capacity: m.capacity,
                isOnline: true,
                lastUpdated: DateTime.now(),
                tareWeight: m.tareWeight,
                linkedInventoryId: m.linkedInventoryId,
                linkedInventoryName: m.linkedInventoryName,
              ),
            )
            .toList();

        if (machines.isEmpty) {
          debugPrint('[API] 0 machines for this user');
        }
      }
    } catch (e) {
      debugPrint('[API] ERROR: $e');
    }

    _loadingDevices = false;
    _refreshAlerts();
    notifyListeners();
  }

  Future<void> reloadDevices() => _loadDevicesFromApi();

  void _startOfflineTimer() {
    _offlineCheckTimer?.cancel();
    //  _offlineCheckTimer = Timer.periodic(const Duration(seconds: 20), (_) {
    //    final now = DateTime.now();
    //    bool changed = false;
    //    for (int i = 0; i < _devices.length; i++) {
    //      final lastMsg = _lastMqttTime[_devices[i].id];
    //      final isStale =
    //          lastMsg == null || now.difference(lastMsg).inSeconds > 35;
    //      if (isStale && _devices[i].isOnline) {
    //        _devices[i] = _devices[i].copyWith(isOnline: false);
    //        changed = true;
    //        debugPrint(
    //          '[OFFLINE] ${_devices[i].name} → offline (${lastMsg == null ? "never seen" : "${now.difference(lastMsg).inSeconds}s ago"})',
    //        );
    //      }
    //    }
    //    if (changed) {
    //      _refreshAlerts();
    //      notifyListeners();
    //    }
    //  });
  }

  void _listenBleStatus() {
    _bleStatusSub = _ble.statusStream.listen((s) {
      _bleStatus = s;
      notifyListeners();
    });
  }

  // MQTT
  Future<void> _connectMqtt() async {
    if (_mqttConnected) return;

    final clientId = 'kitchenbdy_${DateTime.now().millisecondsSinceEpoch}';

    _mqttClient = MqttServerClient(_mqttBroker, clientId)
      ..port = _mqttPort
      ..keepAlivePeriod = 30
      ..autoReconnect = true
      ..logging(on: false)
      ..setProtocolV311();

    _mqttClient!.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(_mqttUser, _mqttPassword)
        .startClean();

    try {
      await _mqttClient!.connect();

      if (_mqttClient!.connectionStatus?.state ==
          MqttConnectionState.connected) {
        _mqttConnected = true;
        notifyListeners();
        debugPrint('[MQTT] Connected ✓  subscribed to devices/+/sensor/+/data');
        _mqttClient!.subscribe('devices/+/sensor/+/data', MqttQos.atMostOnce);
        _mqttClient!.updates?.listen(_onMqttMessage);
      } else {
        debugPrint('[MQTT] Failed: ${_mqttClient!.connectionStatus}');
      }
    } catch (e) {
      debugPrint('[MQTT] connect error: $e');
    }
  }

  void _onMqttMessage(List<MqttReceivedMessage<MqttMessage>> messages) async {
    for (final msg in messages) {
      try {
        final bytes = (msg.payload as MqttPublishMessage).payload.message;
        final jsonStr = utf8.decode(bytes);
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;

        final espId = (json['espId'] as String?) ?? '';
        final slot = (json['slot'] as int?) ?? 0;
        final weight = (json['weight'] as num?)?.toDouble() ?? 0.0;
        if (weight < 0) continue;
        final online = (json['status'] as bool?) ?? true;

        if (espId.isEmpty || slot == 0) continue;

        final sensorId = '${espId}_S$slot';
        _lastMqttTime[sensorId] =
            DateTime.now(); // ← record for offline detection
        debugPrint('[MQTT] → sensorId=$sensorId  weight=$weight');
        debugPrint(
          '[MQTT]   current ids: ${_devices.map((d) => d.id).toList()}',
        );

        // Match by sensorId (normal case)
        int idx = _devices.indexWhere((d) => d.id == sensorId);

        // Match by espId + slot
        if (idx == -1) {
          idx = _devices.indexWhere((d) => d.espId == espId && d.slot == slot);
          if (idx != -1) {
            debugPrint('[MQTT] matched by espId+slot — fixing id to $sensorId');
            _devices[idx] = _devices[idx].copyWith(id: sensorId);
          }
        }

        // Not found — reload from API then try BOTH match strategies again.
        //    This handles the case where API failed at startup, or sensorId
        //    format in DB differs slightly from the MQTT-derived one.
        if (idx == -1) {
          debugPrint('[MQTT] not found locally — reloading from API');
          await _loadDevicesFromApi();

          // 3a: exact id match after reload
          idx = _devices.indexWhere((d) => d.id == sensorId);

          // espId + slot match after reload (catches format mismatches)
          if (idx == -1) {
            idx = _devices.indexWhere(
              (d) => d.espId == espId && d.slot == slot,
            );
            if (idx != -1) {
              debugPrint(
                '[MQTT] post-reload: matched by espId+slot — patching id to $sensorId',
              );
              _devices[idx] = _devices[idx].copyWith(id: sensorId);
            }
          }
        }

        if (idx != -1) {
          // Receiving MQTT data = device is definitely online right now
          _devices[idx] = _devices[idx].copyWith(
            currentWeight: weight,
            isOnline: true,
            lastUpdated: DateTime.now(),
          );
          _refreshAlerts();
          notifyListeners();
          debugPrint('[MQTT] ✓ ${_devices[idx].name} → ${weight}g');
        } else {
          debugPrint('[MQTT] $sensorId not registered to this user — ignored');
        }
      } catch (e) {
        debugPrint('[MQTT] parse error: $e');
      }
    }
  }

  // BLE SCAN
  Future<void> startScan() async {
    _isScanning = true;
    _scannedDevices = [];
    notifyListeners();

    await _bleScanSub?.cancel();
    _bleScanSub = _ble.startScan(timeout: const Duration(seconds: 10)).listen((
      results,
    ) {
      _scannedDevices = results
          .where((r) => r.device.platformName.isNotEmpty)
          .map(
            (r) => {
              'id': r.device.remoteId.str,
              'name': r.device.platformName,
              'mac': r.device.remoteId.str,
              'rssi': '${r.rssi}',
            },
          )
          .toList();
      notifyListeners();
    });

    await Future.delayed(const Duration(seconds: 10));
    await _ble.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  // BLE CONNECT
  Future<bool> connectToDevice(String deviceId) async {
    final scanResults = await FlutterBluePlus.scanResults.first;

    BluetoothDevice? btDevice;
    for (final r in scanResults) {
      if (r.device.remoteId.str == deviceId) {
        btDevice = r.device;
        break;
      }
    }
    if (btDevice == null) {
      for (final d in FlutterBluePlus.connectedDevices) {
        if (d.remoteId.str == deviceId) {
          btDevice = d;
          break;
        }
      }
    }
    if (btDevice == null) return false;

    final success = await _ble.connect(btDevice);
    if (success) {
      _connectedEspId = btDevice.platformName.isNotEmpty
          ? btDevice.platformName.replaceFirst('KBD_', '')
          : 'ESP32_SCALE_1';
      _listenForDiscovery();
    }
    notifyListeners();
    return success;
  }

  void _listenForDiscovery() {
    _bleDiscoverySub?.cancel();
    _bleDiscoverySub = _ble.discoveryStream.listen((notification) {
      if (notification.startsWith('SENSORS:')) {
        final slotsPart = notification.substring('SENSORS:'.length).trim();
        if (slotsPart == 'NONE' || slotsPart.isEmpty) {
          _discoveredSlots = [];
        } else {
          _discoveredSlots = slotsPart
              .split(',')
              .map((s) => int.tryParse(s.trim()) ?? 0)
              .where((n) => n > 0)
              .toList();
        }
        notifyListeners();
      }
    });
  }

  Future<bool> sendWifiCredentials(String ssid, String password) async {
    _discoveredSlots = [];
    notifyListeners();
    final success = await _ble.sendWifiCredentials(ssid, password);
    if (success) Future.delayed(const Duration(seconds: 8), _connectMqtt);
    notifyListeners();
    return success;
  }

  void addScannedDevice({
    required String deviceId,
    required String mac,
    required String customName,
    required String category,
    required String location,
  }) {
    Future.delayed(const Duration(seconds: 3), () async {
      await _loadDevicesFromApi();
      _connectMqtt();
    });
  }

  Future<Map<String, dynamic>> registerDiscoveredSensorsWithError(
    List<Map<String, dynamic>> sensors,
  ) async {
    final result = await WeighingMachineService.registerManyWithError(sensors);
    if (result['ok'] == true) await _loadDevicesFromApi();
    return result;
  }

  Future<bool> registerDiscoveredSensors(
    List<Map<String, dynamic>> sensors,
  ) async {
    final ok = await WeighingMachineService.registerMany(sensors);
    if (ok) await _loadDevicesFromApi();
    return ok;
  }

  Future<void> removeDevice(String sensorId) async {
    _devices.removeWhere((d) => d.id == sensorId);
    _refreshAlerts();
    notifyListeners();
    await WeighingMachineService.removeMachine(sensorId);
  }

  Future<void> updateDeviceMeta(
    String sensorId, {
    String? name,
    String? location,
    String? category,
    double? threshold,
    double? capacity,
    String? unit,
  }) async {
    final idx = _devices.indexWhere((d) => d.id == sensorId);
    if (idx != -1) {
      _devices[idx] = _devices[idx].copyWith(
        name: name ?? _devices[idx].name,
        location: location ?? _devices[idx].location,
        category: category ?? _devices[idx].category,
        threshold: threshold ?? _devices[idx].threshold,
        capacity: capacity ?? _devices[idx].capacity,
        unit: unit ?? _devices[idx].unit,
      );
      _refreshAlerts();
      notifyListeners();
    }
    await WeighingMachineService.updateMachine(
      sensorId,
      name: name,
      location: location,
      category: category,
      threshold: threshold,
      capacity: capacity,
      unit: unit,
    );
  }

  void updateDevice(KitchenDevice updated) {
    final idx = _devices.indexWhere((d) => d.id == updated.id);
    if (idx != -1) {
      _devices[idx] = updated;
      _refreshAlerts();
      notifyListeners();
    }
  }

  void _refreshAlerts() {
    _systemAlerts = buildMockAlerts(_devices);
  }

  void addAlert(AppAlert alert) {
    if (_customAlerts.any((a) => a.id == alert.id)) return;
    _customAlerts.insert(0, alert);
    notifyListeners();
  }

  void markAlertRead(String alertId) {
    for (final list in [_customAlerts, _systemAlerts]) {
      final idx = list.indexWhere((a) => a.id == alertId);
      if (idx != -1) {
        list[idx].isRead = true;
        notifyListeners();
        return;
      }
    }
  }

  void markAllAlertsRead() {
    for (final a in alerts) {
      a.isRead = true;
    }
    notifyListeners();
  }

  void addGroceryItems(List<GroceryItem> items) {
    _groceryItems.addAll(items);
    notifyListeners();
  }

  @override
  void dispose() {
    _bleScanSub?.cancel();
    _bleStatusSub?.cancel();
    _bleDiscoverySub?.cancel();
    _offlineCheckTimer?.cancel();
    _ble.dispose();
    _mqttClient?.disconnect();
    super.dispose();
  }
}
