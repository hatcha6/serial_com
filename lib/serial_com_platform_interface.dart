import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'device.dart';
import 'serial_com_method_channel.dart';

abstract class SerialComPlatform extends PlatformInterface {
  /// Constructs a SerialComPlatform.
  SerialComPlatform() : super(token: _token);

  static final Object _token = Object();

  static SerialComPlatform _instance = MethodChannelSerialCom();

  /// The default instance of [SerialComPlatform] to use.
  ///
  /// Defaults to [MethodChannelSerialCom].
  static SerialComPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SerialComPlatform] when
  /// they register themselves.
  static set instance(SerialComPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion();

  Future<bool> isConnected();

  Future<bool> connect(String port, int baudRate);

  Future<bool> disconnect();

  Future<bool> write(Uint8List data);

  Future<List<Device>> listDevices();

  Future<Uint8List> read();

  Future<bool> requestPermission();
}
