import 'dart:async';
import 'dart:typed_data';

import 'models.dart';
import 'platform_interface/flutter_blue_platform_interface.dart';

export 'models.dart';

class FlutterBluePlus {
  static Future<bool> isBluetoothAvailable() =>
      FlutterBluePlatform.instance.isBluetoothAvailable();

  static void startScan({String? serviceUuid = ''}) =>
      FlutterBluePlatform.instance.startScan(serviceUuid: serviceUuid);

  static void stopScan() => FlutterBluePlatform.instance.stopScan();

  static Stream<BlueScanResult> get scanResultStream {
    return FlutterBluePlatform.instance.scanResultStream
        .map((item) => BlueScanResult.fromMap(item));
  }

  static Future<void> startScanPairedDevices() =>
      FlutterBluePlatform.instance.startScanPairedDevices();
  static Future<void> stopScanPairedDevices() =>
      FlutterBluePlatform.instance.stopScanPairedDevices();

  static Stream<dynamic> get pairedDevicesStream {
    return FlutterBluePlatform.instance.pairedDevicesStream;
  }

  static void connect(String deviceId) =>
      FlutterBluePlatform.instance.connect(deviceId);

  static void disconnect(String deviceId) =>
      FlutterBluePlatform.instance.disconnect(deviceId);

  static void setConnectionHandler(OnConnectionChanged? onConnectionChanged) {
    FlutterBluePlatform.instance.onConnectionChanged = onConnectionChanged;
  }

  static void discoverServices(String deviceId) =>
      FlutterBluePlatform.instance.discoverServices(deviceId);

  static void setServiceHandler(OnServiceDiscovered? onServiceDiscovered) {
    FlutterBluePlatform.instance.onServiceDiscovered = onServiceDiscovered;
  }

  static Future<void> setNotifiable(String deviceId, String service,
      String characteristic, BleInputProperty bleInputProperty) {
    return FlutterBluePlatform.instance
        .setNotifiable(deviceId, service, characteristic, bleInputProperty);
  }

  static void setValueHandler(OnValueChanged? onValueChanged) {
    FlutterBluePlatform.instance.onValueChanged = onValueChanged;
  }

  static Future<void> readValue(
      String deviceId, String service, String characteristic) {
    return FlutterBluePlatform.instance
        .readValue(deviceId, service, characteristic);
  }

  static Future<void> writeValue(
      String deviceId,
      String service,
      String characteristic,
      Uint8List value,
      BleOutputProperty bleOutputProperty) {
    return FlutterBluePlatform.instance.writeValue(
        deviceId, service, characteristic, value, bleOutputProperty);
  }

  static Future<int> requestMtu(String deviceId, int expectedMtu) =>
      FlutterBluePlatform.instance.requestMtu(deviceId, expectedMtu);
}
