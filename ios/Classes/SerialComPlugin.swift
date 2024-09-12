import Flutter
import UIKit
import CoreBluetooth

public class SerialComPlugin: NSObject, FlutterPlugin, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    private var isConnected = false
    private var pendingResult: FlutterResult?
    private var port: String?

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
            self.port = port
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
        guard let uuid = UUID(uuidString: port) else {
            result(FlutterError(code: "INVALID_PORT", message: "Invalid port UUID", details: nil))
            return
        }
        
        // Stop any ongoing scan
        centralManager.stopScan()
        
        // Start scanning for the specific device
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        
        // Set up a timer to stop scanning after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            self?.centralManager.stopScan()
            if !(self?.isConnected ?? false) {
                result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Device not found within timeout", details: nil))
            }
        }
        
        // Store the result callback to be used when the connection is established
        pendingResult = result
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

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard let pendingUUID = UUID(uuidString: port) else { return }
        
        if peripheral.identifier == pendingUUID {
            self.peripheral = peripheral
            centralManager.stopScan()
            centralManager.connect(peripheral, options: nil)
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices(nil)
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

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                self.characteristic = characteristic
                isConnected = true
                pendingResult?(true)
                pendingResult = nil
                return
            }
        }
        
        // If we get here, we didn't find a suitable characteristic
        pendingResult?(FlutterError(code: "NO_WRITABLE_CHARACTERISTIC", message: "No writable characteristic found", details: nil))
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
