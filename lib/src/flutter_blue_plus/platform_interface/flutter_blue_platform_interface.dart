library quick_blue_platform_interface;

import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel.dart';
import 'models.dart';

export 'models.dart';

typedef OnConnectionChanged = void Function(
    String deviceId, BlueConnectionState state);

typedef OnServiceDiscovered = void Function(String deviceId, String serviceId);

typedef OnValueChanged = void Function(
    String deviceId, String characteristicId, Uint8List value);

abstract class FlutterBluePlatform extends PlatformInterface {
  FlutterBluePlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterBluePlatform _instance = MethodChannelQuickBlue();

  static FlutterBluePlatform get instance => _instance;

  static set instance(FlutterBluePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<bool> isBluetoothAvailable();

  void startScan({String? serviceUuid = ''});
  void stopScan();

  Future<void> startScanPairedDevices();
  Future<void> stopScanPairedDevices();

  Stream<dynamic> get scanResultStream;

  Stream<dynamic> get pairedDevicesStream;

  void connect(String deviceId);

  void disconnect(String deviceId);

  OnConnectionChanged? onConnectionChanged;

  void discoverServices(String deviceId);

  OnServiceDiscovered? onServiceDiscovered;

  Future<void> setNotifiable(String deviceId, String service,
      String characteristic, BleInputProperty bleInputProperty);

  OnValueChanged? onValueChanged;

  Future<void> readValue(
      String deviceId, String service, String characteristic);

  Future<void> writeValue(
      String deviceId,
      String service,
      String characteristic,
      Uint8List value,
      BleOutputProperty bleOutputProperty);

  Future<int> requestMtu(String deviceId, int expectedMtu);
}
