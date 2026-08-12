library ble;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:win_ble/win_ble.dart';
import 'package:win_ble/win_file.dart';
import 'package:stream_with_value/stream_with_value.dart';

part 'src/ble.dart';
part 'src/bluetooth_msgs.dart';
part 'src/bluetooth_characteristic.dart';
part 'src/bluetooth_descriptor.dart';
part 'src/bluetooth_device.dart';
part 'src/bluetooth_events.dart';
part 'src/bluetooth_service.dart';
part 'src/bluetooth_utils.dart';
part 'src/guid.dart';
part 'src/utils.dart';

part 'src/windows/windows/bluetooth_characteristic_windows.dart';
part 'src/windows/windows/bluetooth_device_windows.dart';
part 'src/windows/windows/bluetooth_service_windows.dart';
part 'src/windows/windows/ble_windows.dart';
part 'src/windows/windows/util.dart';
part 'src/windows/extension/bluetooth_adapter_state_extension.dart';
part 'src/windows/extension/bluetooth_characteristic_extension.dart';
part 'src/windows/extension/bluetooth_descriptor_extension.dart';
part 'src/windows/extension/bluetooth_service_extension.dart';
part 'src/windows/extension/characteristic_properties_extension.dart';
