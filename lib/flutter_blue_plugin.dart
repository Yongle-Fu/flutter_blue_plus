// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library flutter_blue_plugin;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';

import 'gen/flutterblue.pb.dart' as protos;
import 'src/flutter_blue_plus/flutter_blue_plus.dart';
import 'src/flutter_blue_plus/platform_interface/flutter_blue_platform_interface.dart';

part 'src/bluetooth_characteristic.dart';
part 'src/bluetooth_descriptor.dart';
part 'src/bluetooth_device.dart';
part 'src/bluetooth_service.dart';
part 'src/constants.dart';
part 'src/flutter_blue.dart';
part 'src/flutter_blue_plugin.dart';
part 'src/guid.dart';
