part of flutter_blue_plugin;

class FlutterBlue {
  static FlutterBlue _instance = FlutterBlue();
  static FlutterBlue get instance => _instance;

  /// Checks whether the device supports Bluetooth
  Future<bool> get isAvailable {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      return FlutterBluePlugin.instance.isAvailable;
    }
    return FlutterBluePlus.isBluetoothAvailable();
  }

  /// Checks if Bluetooth functionality is turned on
  Future<bool> get isOn {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      return FlutterBluePlugin.instance.isOn;
    }
    return FlutterBluePlus.isBluetoothAvailable();
  }

  Future<void> requestEnableBluetooth() async {
    if (Platform.isAndroid) {
      await FlutterBluePlugin.instance.requestEnableBluetooth();
    }
  }

  BehaviorSubject<List<ScanResult>> _scanResults = BehaviorSubject.seeded([]);
  Stream<List<ScanResult>> get scanResults {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      return FlutterBluePlugin.instance.scanResults;
    }
    return _scanResults.stream;
  }

  /// Gets the current state of the Bluetooth module
  Stream<BluetoothState> get state async* {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      yield* FlutterBluePlugin.instance.state;
      return;
    }
    yield BluetoothState.on;
  }

  /// Retrieve a list of connected devices
  Future<List<BluetoothDevice>> get connectedDevices {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      return FlutterBluePlugin.instance.connectedDevices;
    }
    return Future.value([]);
  }

  PublishSubject _stopScanPill = new PublishSubject();
  BehaviorSubject<bool> _isScanning = BehaviorSubject.seeded(false);
  Stream<bool> get isScanning {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      return FlutterBluePlugin.instance.isScanning;
    }
    return _isScanning.stream;
  }

  Stream<ScanResult> startScan({
    ScanMode scanMode = ScanMode.lowLatency,
    List<Guid> withServices = const [],
    List<Guid> withDevices = const [],
    Duration? timeout,
    bool allowDuplicates = false,
  }) async* {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      yield* FlutterBluePlugin.instance.scan(
          scanMode: scanMode,
          withServices: withServices,
          withDevices: withDevices,
          timeout: timeout,
          allowDuplicates: allowDuplicates);
      return;
    }

    if (_isScanning.value == true) {
      throw Exception('Another scan is already in progress.');
    }

    // Emit to isScanning
    _isScanning.add(true);

    final killStreams = <Stream>[];
    killStreams.add(_stopScanPill);
    if (timeout != null) {
      killStreams.add(Rx.timer(null, timeout));
    }

    // Clear scan results list
    _scanResults.add(<ScanResult>[]);

    try {
      print('starting scan.');
      FlutterBluePlus.startScan(
          serviceUuid:
              withServices.isNotEmpty ? withServices.first.toString() : '');
    } catch (e) {
      print('Error starting scan.');
      _stopScanPill.add(null);
      _isScanning.add(false);
      throw e;
    }

    yield* FlutterBluePlus.scanResultStream
        .map((r) => ScanResult.fromBlueScanResult(r))
        .map((result) {
      final list = _scanResults.value;
      int index = list.indexOf(result);
      if (index != -1) {
        result.timestamp = DateTime.now().millisecondsSinceEpoch;
        list[index] = result;
      } else {
        list.add(result);
      }
      _scanResults.add(list);
      return result;
    });
  }

  /// Stops a scan for Bluetooth Low Energy devices
  Future stopScan() async {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      await FlutterBluePlugin.instance.stopScan();
      return;
    }

    FlutterBluePlus.stopScan();
    _stopScanPill.add(null);
    _isScanning.add(false);
  }

  // Future setUseHardwareFiltering(bool enabled) async {
  //   if (Platform.isAndroid) {
  //     FlutterBlue.instance.setUseHardwareFiltering(enabled);
  //     return;
  //   }
  // }

  // Future setDataStreamUuid(
  //     String serverUuid, String txUuid, String rxUuid) async {
  //   if (kIsWeb) return;
  //   if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
  //     FlutterBlue.instance.setDataStreamUuid(serverUuid, txUuid, rxUuid);
  //     return;
  //   }
  // }

  /// Log level of the instance, default is all messages (info).
  LogLevel _logLevel = LogLevel.info;
  LogLevel get logLevel => _logLevel;
  Future setLogLevel(LogLevel level) async {
    _logLevel = level;
    if (!Platform.isWindows) {
      FlutterBluePlugin.instance.setLogLevel(level);
      return;
    }
  }

  StreamController<String>? _logRecordController;
  Stream<String> get onLogRecord => _onLogRecord;
  Stream<String> get _onLogRecord {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      return FlutterBluePlugin.instance._onLogRecord;
    }

    if (_logRecordController == null) {
      _logRecordController = StreamController.broadcast();
    }
    return _logRecordController!.stream;
  }

  void log(String message, {LogLevel level = LogLevel.info}) {
    if (level.index <= _logLevel.index) {
      _logRecordController?.add(message);
    }
  }

  StreamSubscription? _pairedDevicesSubscription;
  Map<String, BluetoothDevice> _pairedDevices = {};
  StreamController<DeviceWatcherStatus>? _watcherStatusController;
  DeviceWatcherStatus _watcherStatus = DeviceWatcherStatus.created;
  Future<void> _startScanPairedDevices() async {
    _pairedDevicesSubscription ??=
        FlutterBluePlus.pairedDevicesStream.listen((map) async {
      //log(map.toString());
      final status = map['status'];
      if (status is int && status < DeviceWatcherStatus.values.length) {
        final watcherStatus = DeviceWatcherStatus.values[status];
        _watcherStatus = watcherStatus;
        if (watcherStatus == DeviceWatcherStatus.started) {
          final deviceId = map['deviceId'];
          if (deviceId is String && deviceId.isNotEmpty) {
            final isConnected = map['isConnected'];
            if (isConnected is! bool) return;

            final name = map['name'];
            if (name is String && name.isNotEmpty) {
              final address = map['address'];
              if (!_pairedDevices.containsKey(deviceId) && address is int) {
                if (name.contains('Morpheus')) log(map.toString());
                final device = BluetoothDevice(
                    DeviceIdentifier(address.toString()),
                    name,
                    BluetoothDeviceType.classic);
                device.setIsConnected(isConnected);
                _pairedDevices[deviceId] = device;
              }
            } else {
              final device = _pairedDevices[deviceId];
              if (device != null) {
                device.setIsConnected(isConnected);
              }
            }
          }
        } else if (watcherStatus == DeviceWatcherStatus.enumerationCompleted) {
          await FlutterBluePlus.stopScanPairedDevices();
          _pairedDevicesSubscription?.cancel();
          _pairedDevicesSubscription = null;
        }
        _watcherStatusController?.add(watcherStatus);
      }
    });
    _watcherStatusController ??= StreamController.broadcast();
    _pairedDevices.clear();
    await FlutterBluePlus.startScanPairedDevices();
    await _watcherStatusController!.stream
        .firstWhere((e) => e == DeviceWatcherStatus.enumerationCompleted)
        .timeout(Duration(seconds: 2));
  }

  Future<List<BluetoothDevice>> get a2dpConnectedDevices async {
    if (kIsWeb) return [];
    if (Platform.isWindows) {
      if (_watcherStatusController == null ||
          _watcherStatus == DeviceWatcherStatus.aborted ||
          _watcherStatus == DeviceWatcherStatus.stopped)
        await _startScanPairedDevices();

      return _pairedDevices.values
          .where((e) => e.deviceState == BluetoothDeviceState.connected)
          .toList();
    }
    return FlutterBluePlugin.instance.a2dpConnectedDevices;
  }

  Future<void> requestMtu(String deviceId, int mtu) async {
    if (!Platform.isWindows) return;
    final ret = await FlutterBluePlus.requestMtu(deviceId, mtu);
    log('requestMtu, ret=$ret');
  }

  dispose() {
    _watcherStatusController?.close();
    _watcherStatusController = null;
    _logRecordController?.close();
    _logRecordController = null;
    _pairedDevicesSubscription?.cancel();
    _pairedDevicesSubscription = null;
  }
}

enum DeviceWatcherStatus {
  created,
  started,
  enumerationCompleted,
  stopping,
  stopped,
  aborted
}
