import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plugin/flutter_blue_plugin.dart';

import 'flutter_blue_platform_interface.dart';

class MethodChannelQuickBlue extends FlutterBluePlatform {
  final _messageConnector = BasicMessageChannel(
      'flutter_blue_plugin/message.connector', StandardMessageCodec());
  final MethodChannel _method = MethodChannel('flutter_blue_plugin/method');

  final _eventScanResult = EventChannel('flutter_blue_plugin/event.scanResult');
  final _eventPairedDevices =
      EventChannel('flutter_blue_plugin/event.pairedDevices');

  MethodChannelQuickBlue() {
    if (!Platform.isWindows) return;
    _messageConnector.setMessageHandler(_handleConnectorMessage);
  }

  void _log(String message, {LogLevel level = LogLevel.info}) {
    FlutterBlue.instance.log(message, level: level);
  }

  @override
  Future<bool> isBluetoothAvailable() async {
    bool result = await _method.invokeMethod('isBluetoothAvailable');
    return result;
  }

  @override
  Future<void> startScanPairedDevices() async {
    await _method.invokeMethod('startScanPairedDevices');
  }

  @override
  Future<void> stopScanPairedDevices() async {
    await _method.invokeMethod('stopScanPairedDevices');
  }

  @override
  void startScan({String? serviceUuid = ''}) {
    _method.invokeMethod('startScan', {'serviceUuid': serviceUuid ?? ''}).then(
        (_) => _log('startScan success'));
  }

  @override
  void stopScan() {
    _method.invokeMethod('stopScan').then((_) => _log('stopScan success'));
  }

  Stream<dynamic> get _scanResultStream =>
      _eventScanResult.receiveBroadcastStream({'name': 'scanResult'});

  @override
  Stream<dynamic> get scanResultStream => _scanResultStream;

  Stream<dynamic> get _pairedDevicesStream =>
      _eventPairedDevices.receiveBroadcastStream({'name': 'pairedDevices'});

  @override
  Stream<dynamic> get pairedDevicesStream => _pairedDevicesStream;

  @override
  void connect(String deviceId) {
    _method.invokeMethod('connect', {
      'deviceId': deviceId,
    }).then((_) => _log('connect success'));
  }

  @override
  void disconnect(String deviceId) {
    _method.invokeMethod('disconnect', {
      'deviceId': deviceId,
    }).then((_) => _log('disconnect success'));
  }

  @override
  void discoverServices(String deviceId) {
    _method.invokeMethod('discoverServices', {
      'deviceId': deviceId,
    }).then((_) => _log('discoverServices success'));
  }

  Future<void> _handleConnectorMessage(dynamic message) async {
    _log('_handleConnectorMessage $message', level: LogLevel.debug);
    if (message['ConnectionState'] != null) {
      String deviceId = message['deviceId'];
      BlueConnectionState connectionState =
          BlueConnectionState.parse(message['ConnectionState']);
      onConnectionChanged?.call(deviceId, connectionState);
    } else if (message['ServiceState'] != null) {
      if (message['ServiceState'] == 'discovered') {
        String deviceId = message['deviceId'];
        List<dynamic> services = message['services'];
        for (var s in services) {
          onServiceDiscovered?.call(deviceId, s);
        }
      }
    } else if (message['characteristicValue'] != null) {
      String deviceId = message['deviceId'];
      var characteristicValue = message['characteristicValue'];
      String characteristic = characteristicValue['characteristic'];
      Uint8List value = Uint8List.fromList(characteristicValue['value']);
      // _log('value=$value');
      onValueChanged?.call(deviceId, characteristic, value);
    } else if (message['mtuConfig'] != null) {
      _mtuConfigController.add(message['mtuConfig']);
    }
  }

  @override
  Future<void> setNotifiable(String deviceId, String service,
      String characteristic, BleInputProperty bleInputProperty) async {
    _method.invokeMethod('setNotifiable', {
      'deviceId': deviceId,
      'service': service,
      'characteristic': characteristic,
      'bleInputProperty': bleInputProperty.value,
    }).then((_) => _log('setNotifiable success'));
  }

  @override
  Future<void> readValue(
      String deviceId, String service, String characteristic) async {
    _method.invokeMethod('readValue', {
      'deviceId': deviceId,
      'service': service,
      'characteristic': characteristic,
    }).then((_) => _log('readValue success, characteristic=$characteristic'));
  }

  @override
  Future<void> writeValue(
      String deviceId,
      String service,
      String characteristic,
      Uint8List value,
      BleOutputProperty bleOutputProperty) async {
    _method.invokeMethod('writeValue', {
      'deviceId': deviceId,
      'service': service,
      'characteristic': characteristic,
      'value': value,
      'bleOutputProperty': bleOutputProperty.value,
    }).then((_) {
      _log('writeValue success, characteristic=$characteristic',
          level: LogLevel.debug);
    }).catchError((onError) {
      // Characteristic sometimes unavailable on Android
      throw onError;
    });
  }

  // FIXME Close
  final _mtuConfigController = StreamController<int>.broadcast();

  @override
  Future<int> requestMtu(String deviceId, int expectedMtu) async {
    log('[$deviceId], requestMtu, $expectedMtu');
    _method.invokeMethod('requestMtu', {
      'deviceId': deviceId,
      'expectedMtu': expectedMtu,
    }).then((_) => _log('requestMtu success'));
    return await _mtuConfigController.stream.first;
  }
}
