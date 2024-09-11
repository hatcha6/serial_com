import 'dart:typed_data';

import 'serial_com_platform_interface.dart';

class SerialCom {
  Future<String?> getPlatformVersion() {
    return SerialComPlatform.instance.getPlatformVersion();
  }

  Future<bool> isConnected() {
    return SerialComPlatform.instance.isConnected();
  }

  Future<bool> connect(String port, int baudRate) {
    return SerialComPlatform.instance.connect(port, baudRate);
  }

  Future<bool> disconnect() {
    return SerialComPlatform.instance.disconnect();
  }

  Future<bool> write(Uint8List data) {
    return SerialComPlatform.instance.write(data);
  }
}
