import Cocoa
import FlutterMacOS
import ORSSerial

public class SerialComPlugin: NSObject, FlutterPlugin, ORSSerialPortDelegate {
    private var serialPort: ORSSerialPort?
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
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func listDevices(result: @escaping FlutterResult) {
        let devices = ORSSerialPortManager.shared().availablePorts.map { port -> [String: Any] in
            return [
                "name": port.name,
                "description": port.description,
                "baudRate": port.baudRate,
                "port": port.path
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
        
        serialPort = ORSSerialPort(path: port)
        serialPort?.baudRate = NSNumber(value: baudRate)
        serialPort?.delegate = self
        
        if serialPort?.open() == true {
            result(true)
        } else {
            result(false)
        }
    }
    
    private func disconnect(result: @escaping FlutterResult) {
        serialPort?.close()
        serialPort = nil
        result(true)
    }
    
    private func write(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let data = call.arguments as? FlutterStandardTypedData else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for write", details: nil))
            return
        }
        
        if let serialPort = serialPort, serialPort.isOpen {
            serialPort.send(data.data)
            result(true)
        } else {
            result(false)
        }
    }
    
    private func read(result: @escaping FlutterResult) {
        // This method will be called when data is available
        // For now, we'll return an empty array
        result(FlutterStandardTypedData(bytes: Data()))
    }
    
    // MARK: - ORSSerialPortDelegate
    
    public func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        methodChannel?.invokeMethod("onDataReceived", arguments: FlutterStandardTypedData(bytes: data))
    }
    
    public func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        methodChannel?.invokeMethod("onPortDisconnected", arguments: nil)
    }
    
    public func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        methodChannel?.invokeMethod("onError", arguments: error.localizedDescription)
    }
}
