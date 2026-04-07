import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  static const String _serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String _wifiCharUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String _discCharUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a9';

  BluetoothDevice? _device;
  BluetoothCharacteristic? _wifiChar;
  BluetoothCharacteristic? _discChar;

  StreamSubscription? _discNotifySub;

  // Streams
  final _statusController = StreamController<String>.broadcast();
  final _discoveryController = StreamController<String>.broadcast();

  Stream<String> get statusStream => _statusController.stream;

  /// Emits "SENSORS:1,2,3" when ESP32 finishes scanning after WiFi connect
  Stream<String> get discoveryStream => _discoveryController.stream;

  bool get isConnected => _device != null;

  // SCAN
  Stream<List<ScanResult>> startScan({
    Duration timeout = const Duration(seconds: 10),
  }) {
    FlutterBluePlus.startScan(timeout: timeout, androidUsesFineLocation: true);
    return FlutterBluePlus.scanResults;
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  // CONNECT
  Future<bool> connect(BluetoothDevice device) async {
    try {
      _statusController.add('Connecting via Bluetooth…');
      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 12),
      );
      _device = device;

      _statusController.add('Discovering BLE services…');
      final services = await device.discoverServices();

      for (final svc in services) {
        if (svc.uuid.toString().toLowerCase() != _serviceUuid) continue;

        for (final c in svc.characteristics) {
          final uuid = c.uuid.toString().toLowerCase();

          if (uuid == _wifiCharUuid) {
            _wifiChar = c;
          }

          if (uuid == _discCharUuid) {
            _discChar = c;
            // Subscribe to notifications — ESP32 will push "SENSORS:1,2,3"
            await c.setNotifyValue(true);
            _discNotifySub = c.lastValueStream.listen((bytes) {
              if (bytes.isNotEmpty) {
                final msg = utf8.decode(bytes).trim();
                if (msg.isNotEmpty) {
                  _discoveryController.add(msg);
                }
              }
            });
          }
        }
      }

      if (_wifiChar != null) {
        _statusController.add('Connected — ready for WiFi setup');
        return true;
      }

      _statusController.add('KitchenBDY scale service not found on device');
      return false;
    } catch (e) {
      _statusController.add('Connection failed: $e');
      return false;
    }
  }

  // SEND WIFI CREDENTIALS
  /// ESP32 will connect to WiFi → MQTT → scan sensors → notify "SENSORS:1,2,3"
  Future<bool> sendWifiCredentials(String ssid, String password) async {
    if (_wifiChar == null) return false;
    try {
      _statusController.add('Sending Wi-Fi credentials…');
      await _wifiChar!.write(
        utf8.encode('$ssid|$password'),
        withoutResponse: false,
      );
      _statusController.add('Credentials sent — waiting for sensor discovery…');
      return true;
    } catch (e) {
      _statusController.add('Send failed: $e');
      return false;
    }
  }

  // DISCONNECT
  Future<void> disconnect() async {
    await _discNotifySub?.cancel();
    await _device?.disconnect();
    _device = null;
    _wifiChar = null;
    _discChar = null;
  }

  void dispose() {
    _discNotifySub?.cancel();
    _statusController.close();
    _discoveryController.close();
  }
}
