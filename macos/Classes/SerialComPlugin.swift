import Cocoa
import FlutterMacOS
import SwiftSerial
import IOBluetooth

public class SerialComPlugin: NSObject, FlutterPlugin {
    private var serialPort: SerialPort?
    private var methodChannel: FlutterMethodChannel?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "serial_com", binaryMessenger: registrar.messenger)
        let instance = SerialComPlugin()
        instance.methodChannel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
        case "listDevices":
            listDevices(result: result)
        case "isConnected":
            result(serialPort?.isOpen ?? false)
        case "connect":
            connect(call: call, result: result)
        case "disconnect":
            disconnect(result: result)
        case "write":
            write(call: call, result: result)
        case "read":
            read(result: result)
        case "requestPermission":
            requestPermission(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func listDevices(result: @escaping FlutterResult) {
        let devices = SerialPort.getAvailablePorts().map { portPath -> [String: Any] in
            return [
                "name": URL(fileURLWithPath: portPath).lastPathComponent,
                "description": "Serial Port",
                "baudRate": 9600, // Default baud rate
                "port": portPath
            ]
        }
        result(devices)
    }
    
    private func connect(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let port = args["port"] as? String,
              let baudRate = args["baudRate"] as? Int else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for connect", details: nil))
            return
        }
        
        do {
            serialPort = try SerialPort(path: port)
            try serialPort?.setSettings(receiveRate: .baud9600, transmitRate: .baud9600, minimumBytesToRead: 1)
            try serialPort?.openPort()
            result(true)
        } catch {
            result(FlutterError(code: "CONNECTION_ERROR", message: "Failed to connect: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func disconnect(result: @escaping FlutterResult) {
        do {
            try serialPort?.closePort()
            serialPort = nil
            result(true)
        } catch {
            result(FlutterError(code: "DISCONNECT_ERROR", message: "Failed to disconnect: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func write(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let data = call.arguments as? FlutterStandardTypedData else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for write", details: nil))
            return
        }
        
        do {
            try serialPort?.writeData(data.data)
            result(true)
        } catch {
            result(FlutterError(code: "WRITE_ERROR", message: "Failed to write: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func read(result: @escaping FlutterResult) {
        do {
            if let data = try serialPort?.readData() {
                result(FlutterStandardTypedData(bytes: data))
            } else {
                result(FlutterError(code: "READ_ERROR", message: "Failed to read data", details: nil))
            }
        } catch {
            result(FlutterError(code: "READ_ERROR", message: "Failed to read: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func requestPermission(result: @escaping FlutterResult) {
        let ioDialogService = IOBluetoothDialogService()
        ioDialogService.requestAccess { (granted: Bool) in
            DispatchQueue.main.async {
                result(granted)
            }
        }
    }
}
