package ly.chinchilla.serial_com

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.hardware.usb.UsbManager
import android.content.Context
import com.hoho.android.usbserial.driver.UsbSerialPort
import com.hoho.android.usbserial.driver.UsbSerialProber
import java.io.IOException

/** SerialComPlugin */
class SerialComPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private var port: UsbSerialPort? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "serial_com")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
      "listDevices" -> listDevices(result)
      "isConnected" -> result.success(port?.isOpen == true)
      "connect" -> connect(call, result)
      "disconnect" -> disconnect(result)
      "write" -> write(call, result)
      "read" -> read(result)
      else -> result.notImplemented()
    }
  }

  private fun listDevices(result: Result) {
    val manager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    val availableDrivers = UsbSerialProber.getDefaultProber().findAllDrivers(manager)
    val devices = availableDrivers.flatMap { driver ->
      driver.ports.map { port ->
        mapOf(
          "name" to driver.javaClass.simpleName,
          "description" to driver.device.deviceName,
          "baudRate" to 9600,
          "port" to port.portNumber.toString(),
          "serialNumber" to driver.device.serialNumber,
          "manufacturer" to driver.device.manufacturerName,
          "product" to driver.device.productName
        )
      }
    }
    result.success(devices)
  }

  private fun connect(call: MethodCall, result: Result) {
    val portName = call.argument<String>("port") ?: return result.error("INVALID_ARGUMENT", "Port is required", null)
    val baudRate = call.argument<Int>("baudRate") ?: 9600

    val manager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    val availableDrivers = UsbSerialProber.getDefaultProber().findAllDrivers(manager)
    val driver = availableDrivers.firstOrNull { it.ports.any { port -> port.portNumber.toString() == portName } }
      ?: return result.error("DEVICE_NOT_FOUND", "No device found for the given port", null)

    port = driver.ports[portName.toInt()]
    
    try {
      port?.open(manager.openDevice(driver.device))
      port?.setParameters(baudRate, UsbSerialPort.DATABITS_8, UsbSerialPort.STOPBITS_1, UsbSerialPort.PARITY_NONE)
      result.success(true)
    } catch (e: IOException) {
      result.error("CONNECTION_FAILED", "Failed to connect to the device", e.message)
    }
  }

  private fun disconnect(result: Result) {
    try {
      port?.close()
      port = null
      result.success(true)
    } catch (e: IOException) {
      result.error("DISCONNECT_FAILED", "Failed to disconnect from the device", e.message)
    }
  }

  private fun write(call: MethodCall, result: Result) {
    val data = call.arguments as ByteArray
    try {
      port?.write(data, 1000)
      result.success(true)
    } catch (e: IOException) {
      result.error("WRITE_FAILED", "Failed to write data to the device", e.message)
    }
  }

  private fun read(result: Result) {
    try {
      val buffer = ByteArray(1024)
      val bytesRead = port?.read(buffer, 1000) ?: 0
      result.success(buffer.copyOf(bytesRead))
    } catch (e: IOException) {
      result.error("READ_FAILED", "Failed to read data from the device", e.message)
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
