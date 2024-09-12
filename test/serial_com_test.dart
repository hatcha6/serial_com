import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:serial_com/device.dart';
import 'package:serial_com/serial_com.dart';
import 'package:serial_com/serial_com_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSerialComPlatform
    with MockPlatformInterfaceMixin
    implements SerialComPlatform {
  bool _isConnected = false;
  final List<Device> _devices = const [
    Device(
      name: 'Arduino Uno',
      description: 'Arduino Uno R3',
      baudRate: 9600,
      port: '/dev/ttyACM0',
      serialNumber: 'A12345',
      manufacturer: 'Arduino',
      product: 'Uno',
      protocol: 'USB',
      protocolVersion: '2.0',
    ),
    Device(
      name: 'Raspberry Pi Pico',
      description: 'RP2040 Microcontroller',
      baudRate: 115200,
      port: '/dev/ttyUSB0',
      serialNumber: 'RP54321',
      manufacturer: 'Raspberry Pi',
      product: 'Pico',
      protocol: 'USB',
      protocolVersion: '2.0',
    ),
  ];
  final List<int> _buffer = [];

  @override
  Future<String?> getPlatformVersion() => Future.value('Flutter 3.10.0');

  @override
  Future<bool> connect(String port, int baudRate) async {
    _devices.firstWhere((d) => d.port == port && d.baudRate == baudRate,
        orElse: () => throw Exception('Device not found'));
    _isConnected = true;
    return _isConnected;
  }

  @override
  Future<bool> disconnect() async {
    _isConnected = false;
    _buffer.clear();
    return true;
  }

  @override
  Future<bool> isConnected() async => _isConnected;

  @override
  Future<List<Device>> listDevices() async => _devices;

  @override
  Future<Uint8List> read() async {
    if (!_isConnected) throw Exception('Not connected');
    final data = Uint8List.fromList(_buffer);
    _buffer.clear();
    return data;
  }

  @override
  Future<bool> write(Uint8List data) async {
    if (!_isConnected) throw Exception('Not connected');
    _buffer.addAll(data);
    return true;
  }

  @override
  Future<bool> requestPermission() => Future.value(true);
}

void main() {
  late SerialCom serialComPlugin;
  late MockSerialComPlatform fakePlatform;

  setUp(() {
    serialComPlugin = SerialCom();
    fakePlatform = MockSerialComPlatform();
    SerialComPlatform.instance = fakePlatform;
  });

  test('getPlatformVersion', () async {
    expect(await serialComPlugin.getPlatformVersion(), 'Flutter 3.10.0');
  });

  test('listDevices returns correct devices', () async {
    final devices = await serialComPlugin.listDevices();
    expect(devices.length, 2);
    expect(devices[0].name, 'Arduino Uno');
    expect(devices[1].name, 'Raspberry Pi Pico');
  });

  test('connect succeeds with valid device', () async {
    expect(await serialComPlugin.connect('/dev/ttyACM0', 9600), true);
  });

  test('connect throws exception with invalid device', () async {
    expect(
        () => serialComPlugin.connect('/dev/invalid', 9600), throwsException);
  });

  test('isConnected returns correct state', () async {
    expect(await serialComPlugin.isConnected(), false);
    await serialComPlugin.connect('/dev/ttyACM0', 9600);
    expect(await serialComPlugin.isConnected(), true);
  });

  test('disconnect succeeds', () async {
    await serialComPlugin.connect('/dev/ttyACM0', 9600);
    expect(await serialComPlugin.disconnect(), true);
    expect(await serialComPlugin.isConnected(), false);
  });

  test('write and read work correctly', () async {
    await serialComPlugin.connect('/dev/ttyACM0', 9600);
    final dataToWrite = Uint8List.fromList([1, 2, 3, 4, 5]);
    expect(await serialComPlugin.write(dataToWrite), true);
    final readData = await serialComPlugin.read();
    expect(readData, equals(dataToWrite));
  });

  test('read throws exception when not connected', () async {
    expect(() => serialComPlugin.read(), throwsException);
  });

  test('write throws exception when not connected', () async {
    final dataToWrite = Uint8List.fromList([1, 2, 3, 4, 5]);
    expect(() => serialComPlugin.write(dataToWrite), throwsException);
  });
}
