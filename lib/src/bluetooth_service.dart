// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plugin;

class BluetoothService {
  final Guid uuid;
  final DeviceIdentifier deviceId;
  final bool isPrimary;
  final List<BluetoothCharacteristic> characteristics;
  final List<BluetoothService> includedServices;

  BluetoothService(this.uuid, this.deviceId, this.isPrimary,
      this.characteristics, this.includedServices);

  BluetoothService.fromProto(protos.BluetoothService p)
      : uuid = new Guid(p.uuid),
        deviceId = new DeviceIdentifier(p.remoteId),
        isPrimary = p.isPrimary,
        characteristics = p.characteristics
            .map((c) => new BluetoothCharacteristic.fromProto(c))
            .toList(),
        includedServices = p.includedServices
            .map((s) => new BluetoothService.fromProto(s))
            .toList();

  @override
  String toString() {
    return 'BluetoothService{uuid: $uuid, deviceId: $deviceId, isPrimary: $isPrimary, characteristics: $characteristics, includedServices: $includedServices}';
  }
}
