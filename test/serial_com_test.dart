import 'package:flutter_test/flutter_test.dart';
import 'package:serial_com/serial_com.dart';
import 'package:serial_com/serial_com_platform_interface.dart';
import 'package:serial_com/serial_com_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSerialComPlatform
    with MockPlatformInterfaceMixin
    implements SerialComPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final SerialComPlatform initialPlatform = SerialComPlatform.instance;

  test('$MethodChannelSerialCom is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelSerialCom>());
  });

  test('getPlatformVersion', () async {
    SerialCom serialComPlugin = SerialCom();
    MockSerialComPlatform fakePlatform = MockSerialComPlatform();
    SerialComPlatform.instance = fakePlatform;

    expect(await serialComPlugin.getPlatformVersion(), '42');
  });
}
