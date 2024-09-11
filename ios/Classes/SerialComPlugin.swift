import Flutter
import UIKit

public class SerialComPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "serial_com", binaryMessenger: registrar.messenger())
    let instance = SerialComPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "listDevices":
      result([])
    case "connect":
    case "disconnect":
    case "write":
    case "read":
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
