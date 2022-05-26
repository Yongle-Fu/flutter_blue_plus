// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plugin;

typedef IsServiceDiscovered = bool Function(Iterable<String> serviceIds);

class BluetoothDevice {
  final DeviceIdentifier id;
  final String name;
  final BluetoothDeviceType type;

  BluetoothDevice.fromProto(protos.BluetoothDevice p)
      : id = new DeviceIdentifier(p.remoteId),
        name = p.name,
        type = BluetoothDeviceType.values[p.type.value];

  BluetoothDevice(this.id, this.name, this.type);

  String get deviceId => id.toString();

  void setIsConnected(bool isConnected) {
    if (!Platform.isWindows) return;
    _deviceState = isConnected
        ? BluetoothDeviceState.connected
        : BluetoothDeviceState.disconnected;
  }

  BluetoothDeviceState get deviceState => _deviceState;
  BluetoothDeviceState _deviceState = BluetoothDeviceState.disconnected;
  // TODO: multi device
  _onConnectivityChanged(String deviceId, BlueConnectionState state) {
    final deviceState = state == BlueConnectionState.connected
        ? BluetoothDeviceState.connected
        : BluetoothDeviceState.disconnected;
    if (state == BlueConnectionState.connected) {
      _connectTimeout?.cancel();
      _connectTimeout = null;
      _completer?.complete(true);
      _completer = null;
    }
    if (deviceState == _deviceState) return;

    FlutterBlue.instance.log(
        '_onConnectivityChanged this.deviceId=${this.deviceId}, $deviceId, ${state.value}');
    if (this.deviceId == deviceId) {
      _deviceState = deviceState;
      _stateController?.add(_deviceState);
    }
  }

  Timer? _connectTimeout;
  Completer<void>? _completer;

  BehaviorSubject<bool> _isDiscoveringServices = BehaviorSubject.seeded(false);
  Stream<bool> get isDiscoveringServices => _isDiscoveringServices.stream;

  BehaviorSubject<List<BluetoothService>> _services =
      BehaviorSubject.seeded([]);

  IsServiceDiscovered? isServiceDiscovered;
  Iterable<String> get bleServiceIds => _bleServices.keys;
  Map<String, BluetoothService> _bleServices = {};
  // TODO: multi device
  void _onServiceDiscovered(String deviceId, String serviceId) {
    FlutterBlue.instance.log('_onServiceDiscovered $deviceId, $serviceId');
    if (this.deviceId == deviceId && _bleServices.containsKey(serviceId)) {
      final service = BluetoothService(
          Guid(serviceId), DeviceIdentifier(deviceId), false, [], []);
      _bleServices[serviceId] = service;

      if (isServiceDiscovered != null && isServiceDiscovered!(bleServiceIds)) {
        _isDiscoveringServices.add(false);
        _services.add(_bleServices.values.toList());
      }
    }
  }

  /// Establishes a connection to the Bluetooth Device.
  Future<void> connect({
    Duration? timeout,
    bool autoConnect = false,
    int mtu = 0, // 23~241
    int connectionPriority = -1, // 0~2
  }) async {
    if (Platform.isWindows) {
      FlutterBluePlus.setConnectionHandler(_onConnectivityChanged);
      FlutterBluePlus.connect(deviceId);
      _completer ??= Completer<bool>();
      _connectTimeout?.cancel();
      _connectTimeout = Timer(timeout ?? Duration(seconds: 7), () {
        _completer?.complete(false);
      });
      return _completer!.future;
    }

    var request = protos.ConnectRequest.create()
      ..remoteId = deviceId
      ..androidAutoConnect = autoConnect;

    if (Platform.isAndroid) {
      request.mtu = mtu;
      request.connectionPriority = connectionPriority;
    }

    Timer? timer;
    if (timeout != null) {
      timer = Timer(timeout, () {
        disconnect();
        throw TimeoutException('Failed to connect in time.', timeout);
      });
    }

    FlutterBluePlugin.instance._channel
        .invokeMethod('connect', request.writeToBuffer());

    await state.firstWhere((s) => s == BluetoothDeviceState.connected);

    timer?.cancel();
  }

  /// Cancels connection to the Bluetooth Device
  void disconnect() {
    if (Platform.isWindows) {
      FlutterBluePlus.disconnect(deviceId);
      return;
    }
    FlutterBluePlugin.instance._channel.invokeMethod('disconnect', deviceId);
  }

  /// Discovers services offered by the remote device as well as their characteristics and descriptors
  Future<List<BluetoothService>> discoverServices(
      {Duration timeout = const Duration(seconds: 3)}) async {
    if (_deviceState != BluetoothDeviceState.connected) {
      return Future.error(new Exception(
          'Cannot discoverServices while device is not connected. currentState=$_deviceState'));
    }

    if (Platform.isWindows) {
      FlutterBluePlus.setServiceHandler(_onServiceDiscovered);
      FlutterBluePlus.discoverServices(deviceId);
      _isDiscoveringServices.add(true);
      return _services.first.timeout(timeout);
    }

    var response = FlutterBluePlugin.instance._methodStream
        .where((m) => m.method == "DiscoverServicesResult")
        .map((m) => m.arguments)
        .map((buffer) => new protos.DiscoverServicesResult.fromBuffer(buffer))
        .where((p) => p.remoteId == id.toString())
        .map((p) => p.services)
        .map((s) => s.map((p) => new BluetoothService.fromProto(p)).toList())
        .first
        .timeout(timeout)
        .then((list) {
      _services.add(list);
      _isDiscoveringServices.add(false);
      return list;
    });

    await FlutterBluePlugin.instance._channel
        .invokeMethod('discoverServices', id.toString());

    _isDiscoveringServices.add(true);

    return response;
  }

  /// Returns a list of Bluetooth GATT services offered by the remote device
  /// This function requires that discoverServices has been completed for this device
  Stream<List<BluetoothService>> get services async* {
    if (Platform.isWindows) {
      if (_bleServices.isEmpty) {
        if (_isDiscoveringServices.value != true)
          yield await discoverServices();
      } else {
        yield _bleServices.values.toList();
        return;
      }
    } else {
      yield await FlutterBluePlugin.instance._channel
          .invokeMethod('services', id.toString())
          .then((buffer) =>
              new protos.DiscoverServicesResult.fromBuffer(buffer).services)
          .then(
              (i) => i.map((s) => new BluetoothService.fromProto(s)).toList());
      yield* _services.stream;
    }
  }

  Future<void> setNotifiable(
      String service, String characteristic, bool enabled) {
    return FlutterBluePlus.setNotifiable(deviceId, service, characteristic,
        enabled ? BleInputProperty.notification : BleInputProperty.disabled);
  }

  void setValueHandler(OnValueChanged? onValueChanged) {
    FlutterBluePlus.setValueHandler(onValueChanged);
  }

  Future<void> writeValue(
      String service, String characteristic, Uint8List value,
      {bool withoutResponse = true}) {
    return FlutterBluePlus.writeValue(
        deviceId,
        service,
        characteristic,
        value,
        withoutResponse
            ? BleOutputProperty.withoutResponse
            : BleOutputProperty.withResponse);
  }

  Future readValue(String service, String characteristic) async {
    await FlutterBluePlus.readValue(deviceId, service, characteristic);
  }

  // ignore: close_sinks
  StreamController<BluetoothDeviceState>? _stateController;
  Stream<BluetoothDeviceState> get _stateStream {
    _stateController ??= StreamController<BluetoothDeviceState>.broadcast();
    return _stateController!.stream;
  }

  /// The current connection state of the device
  Stream<BluetoothDeviceState> get state async* {
    if (Platform.isWindows) {
      yield _deviceState;
      yield* _stateStream;
      return;
    }

    yield await FlutterBluePlugin.instance._channel
        .invokeMethod('deviceState', id.toString())
        .then((buffer) => new protos.DeviceStateResponse.fromBuffer(buffer))
        .then((p) => BluetoothDeviceState.values[p.state.value]);

    yield* FlutterBluePlugin.instance._methodStream
        .where((m) => m.method == "DeviceState")
        .map((m) => m.arguments)
        .map((buffer) => new protos.DeviceStateResponse.fromBuffer(buffer))
        .where((p) => p.remoteId == id.toString())
        .map((p) => BluetoothDeviceState.values[p.state.value]);
  }

  /// The MTU size in bytes
  Stream<int> get mtu async* {
    yield await FlutterBluePlugin.instance._channel
        .invokeMethod('mtu', id.toString())
        .then((buffer) => new protos.MtuSizeResponse.fromBuffer(buffer))
        .then((p) => p.mtu);

    yield* FlutterBluePlugin.instance._methodStream
        .where((m) => m.method == "MtuSize")
        .map((m) => m.arguments)
        .map((buffer) => new protos.MtuSizeResponse.fromBuffer(buffer))
        .where((p) => p.remoteId == id.toString())
        .map((p) => p.mtu);
  }

  /// Request to change the MTU Size
  /// Throws error if request did not complete successfully
  Future<void> requestMtu(int desiredMtu) async {
    if (Platform.isWindows) {
      FlutterBluePlus.requestMtu(deviceId, desiredMtu);
      return;
    }

    if (!Platform.isAndroid) return;

    var request = protos.MtuSizeRequest.create()
      ..remoteId = id.toString()
      ..mtu = desiredMtu;

    return FlutterBluePlugin.instance._channel
        .invokeMethod('requestMtu', request.writeToBuffer());
  }

  /// Indicates whether the Bluetooth Device can send a write without response
  Future<bool> get canSendWriteWithoutResponse =>
      new Future.error(new UnimplementedError());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'BluetoothDevice{id: $id, name: $name, type: $type, isDiscoveringServices: ${_isDiscoveringServices.value}, _services: ${_services.value}';
  }
}

enum BluetoothDeviceType { unknown, classic, le, dual }

enum BluetoothDeviceState { disconnected, connecting, connected, disconnecting }
