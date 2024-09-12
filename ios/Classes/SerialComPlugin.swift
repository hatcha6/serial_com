import Flutter
import UIKit
import CoreBluetooth

public class SerialComPlugin: NSObject, FlutterPlugin, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    private var isConnected = false
    private var pendingResult: FlutterResult?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "serial_com", binaryMessenger: registrar.messenger())
        let instance = SerialComPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "listDevices":
            listDevices(result: result)
        case "connect":
            guard let args = call.arguments as? [String: Any],
                  let port = args["port"] as? String,
                  let baudRate = args["baudRate"] as? Int else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for connect", details: nil))
                return
            }
            connect(port: port, baudRate: baudRate, result: result)
        case "disconnect":
            disconnect(result: result)
        case "write":
            guard let args = call.arguments as? [String: Any],
                  let data = args["data"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for write", details: nil))
                return
            }
            write(data: data.data, result: result)
        case "read":
            read(result: result)
        case "isConnected":
            result(isConnected)
        case "requestPermission":
            requestPermission(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func listDevices(result: @escaping FlutterResult) {
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: nil)
            // In a real implementation, you'd collect devices and return them.
            // For simplicity, we're just returning an empty list here.
            result([])
        } else {
            result(FlutterError(code: "BLUETOOTH_OFF", message: "Bluetooth is not powered on", details: nil))
        }
    }

    private func connect(port: String, baudRate: Int, result: @escaping FlutterResult) {
        // In a real implementation, you'd use the port and baudRate to connect to the device.
        // For simplicity, we're just setting isConnected to true here.
        isConnected = true
        result(true)
    }

    private func disconnect(result: @escaping FlutterResult) {
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        isConnected = false
        result(true)
    }

    private func write(data: Data, result: @escaping FlutterResult) {
        guard isConnected, let characteristic = characteristic else {
            result(FlutterError(code: "NOT_CONNECTED", message: "Not connected to a device", details: nil))
            return
        }
        peripheral?.writeValue(data, for: characteristic, type: .withResponse)
        result(true)
    }

    private func read(result: @escaping FlutterResult) {
        guard isConnected, let characteristic = characteristic else {
            result(FlutterError(code: "NOT_CONNECTED", message: "Not connected to a device", details: nil))
            return
        }
        pendingResult = result
        peripheral?.readValue(for: characteristic)
    }

    // MARK: - CBCentralManagerDelegate

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Handle state changes if needed
    }

    // MARK: - CBPeripheralDelegate

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            pendingResult?(FlutterError(code: "READ_ERROR", message: error.localizedDescription, details: nil))
        } else if let value = characteristic.value {
            pendingResult?(FlutterStandardTypedData(bytes: value))
        } else {
            pendingResult?(FlutterError(code: "NO_DATA", message: "No data received", details: nil))
        }
        pendingResult = nil
    }

    private func requestPermission(result: @escaping FlutterResult) {
        switch CBCentralManager.authorization {
        case .allowedAlways:
            result(true)
        case .notDetermined:
            // iOS will automatically prompt for permission when we start scanning
            centralManager.scanForPeripherals(withServices: nil, options: nil)
            centralManager.stopScan()
            result(true)
        case .restricted, .denied:
            result(false)
        @unknown default:
            result(FlutterError(code: "UNKNOWN_AUTH_STATUS", message: "Unknown authorization status", details: nil))
        }
    }
}
