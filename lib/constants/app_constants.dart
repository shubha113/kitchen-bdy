class AppConstants {
  AppConstants._();

  static const String appName = 'Kitchen BDY';
  static const String appTagline = 'The Intelligent Pantry';
  static const String appVersion = '1.0.0';

  // MQTT topics format (for firmware integration later)
  static const String mqttTopicBase = 'kitchen_bdy';
  // topic: kitchen_bdy/{userId}/{deviceId}/weight
  // topic: kitchen_bdy/{userId}/{deviceId}/status
  // topic: kitchen_bdy/{userId}/{deviceId}/battery

  // BLE service & characteristic UUIDs (for firmware)
  static const String bleServiceUUID = '12345678-1234-1234-1234-123456789012';
  static const String bleWeightCharUUID =
      '12345678-1234-1234-1234-123456789013';
  static const String bleWifiCredCharUUID =
      '12345678-1234-1234-1234-123456789014';
  static const String bleMqttCredCharUUID =
      '12345678-1234-1234-1234-123456789015';
  static const String bleStatusCharUUID =
      '12345678-1234-1234-1234-123456789016';

  // MQTT JSON message format documentation
  // Incoming (device → app):
  // {
  //   "device_id": "KBD_001",
  //   "weight": 450.5,
  //   "unit": "g",
  //   "battery": 85,
  //   "rssi": -65,
  //   "timestamp": "2024-01-15T10:30:00Z"
  // }
  //
  // Outgoing (app → device via BLE provisioning):
  // {
  //   "ssid": "HomeWifi",
  //   "password": "...",
  //   "mqtt_host": "broker.example.com",
  //   "mqtt_port": 1883,
  //   "device_id": "KBD_001",
  //   "user_id": "usr_abc"
  // }

  static const List<String> categories = [
    'All',
    'Grains',
    'Spices',
    'Dairy',
    'Oils',
    'Pulses',
    'Beverages',
    'Snacks',
    'Other',
  ];

  static const List<String> units = ['g', 'kg', 'ml', 'L', 'pcs'];

  static const int scanDurationSeconds = 10;
  static const double defaultThresholdGrams = 200.0;
}
