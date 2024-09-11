import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'device.dart';
import 'serial_com_platform_interface.dart';

/// An implementation of [SerialComPlatform] that uses method channels.
class MethodChannelSerialCom extends SerialComPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('serial_com');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<List<Device>> listDevices() async {
    final devices = await methodChannel
        .invokeMethod<List<Map<String, dynamic>>>('listDevices');
    return devices?.map((device) => Device.fromJson(device)).toList() ?? [] ;
  }

  @override
  Future<bool> isConnected() async {
    final isConnected = await methodChannel.invokeMethod<bool>('isConnected');
    return isConnected ?? false;
  }

  @override
  Future<bool> connect(String port, int baudRate) async {
    final connected = await methodChannel
        .invokeMethod<bool>('connect', {'port': port, 'baudRate': baudRate});
    return connected ?? false;
  }

  @override
  Future<bool> disconnect() async {
    final disconnected = await methodChannel.invokeMethod<bool>('disconnect');
    return disconnected ?? false;
  }

  @override
  Future<Uint8List> read() async {
    final data = await methodChannel.invokeMethod<Uint8List>('read');
    return data ?? Uint8List.fromList([]);
  }

  @override
  Future<bool> write(Uint8List data) async {
    final written = await methodChannel.invokeMethod<bool>('write', data);
    return written ?? false;
  }
}
