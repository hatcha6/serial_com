#include "serial_com_plugin.h"
#include <windows.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <memory>
#include <sstream>
#include <vector>

namespace serial_com {

class SerialPort {
 public:
  SerialPort() : handle_(INVALID_HANDLE_VALUE) {}
  ~SerialPort() { Close(); }

  bool Open(const std::string& port, int baudRate) {
    Close();
    handle_ = CreateFileA(port.c_str(), GENERIC_READ | GENERIC_WRITE, 0, NULL,
                          OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (handle_ == INVALID_HANDLE_VALUE) return false;

    DCB dcb = {0};
    dcb.DCBlength = sizeof(DCB);
    if (!GetCommState(handle_, &dcb)) {
      Close();
      return false;
    }

    dcb.BaudRate = baudRate;
    dcb.ByteSize = 8;
    dcb.Parity = NOPARITY;
    dcb.StopBits = ONESTOPBIT;

    if (!SetCommState(handle_, &dcb)) {
      Close();
      return false;
    }

    COMMTIMEOUTS timeouts = {0};
    timeouts.ReadIntervalTimeout = 50;
    timeouts.ReadTotalTimeoutConstant = 50;
    timeouts.ReadTotalTimeoutMultiplier = 10;
    timeouts.WriteTotalTimeoutConstant = 50;
    timeouts.WriteTotalTimeoutMultiplier = 10;

    if (!SetCommTimeouts(handle_, &timeouts)) {
      Close();
      return false;
    }

    return true;
  }

  void Close() {
    if (handle_ != INVALID_HANDLE_VALUE) {
      CloseHandle(handle_);
      handle_ = INVALID_HANDLE_VALUE;
    }
  }

  bool IsConnected() const { return handle_ != INVALID_HANDLE_VALUE; }

  bool Write(const std::vector<uint8_t>& data) {
    if (!IsConnected()) return false;
    DWORD bytesWritten;
    return WriteFile(handle_, data.data(), data.size(), &bytesWritten, NULL) &&
           bytesWritten == data.size();
  }

  std::vector<uint8_t> Read() {
    if (!IsConnected()) return {};
    std::vector<uint8_t> buffer(1024);
    DWORD bytesRead;
    if (ReadFile(handle_, buffer.data(), buffer.size(), &bytesRead, NULL)) {
      buffer.resize(bytesRead);
      return buffer;
    }
    return {};
  }

 private:
  HANDLE handle_;
};

class SerialComPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
    auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        registrar->messenger(), "serial_com",
        &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<SerialComPlugin>();

    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto& call, auto result) {
          plugin_pointer->HandleMethodCall(call, std::move(result));
        });

    registrar->AddPlugin(std::move(plugin));
  }

  SerialComPlugin() {}

  virtual ~SerialComPlugin() {}

 private:
  SerialPort serial_port_;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (method_call.method_name().compare("getPlatformVersion") == 0) {
      std::ostringstream version_stream;
      version_stream << "Windows ";
      if (IsWindows10OrGreater()) {
        version_stream << "10+";
      } else if (IsWindows8OrGreater()) {
        version_stream << "8";
      } else if (IsWindows7OrGreater()) {
        version_stream << "7";
      }
      result->Success(flutter::EncodableValue(version_stream.str()));
    } else if (method_call.method_name().compare("isConnected") == 0) {
      result->Success(flutter::EncodableValue(serial_port_.IsConnected()));
    } else if (method_call.method_name().compare("connect") == 0) {
      const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
      if (arguments) {
        auto port = std::get<std::string>(arguments->at(flutter::EncodableValue("port")));
        auto baudRate = std::get<int>(arguments->at(flutter::EncodableValue("baudRate")));
        result->Success(flutter::EncodableValue(serial_port_.Open(port, baudRate)));
      } else {
        result->Error("InvalidArguments", "Invalid arguments for connect");
      }
    } else if (method_call.method_name().compare("disconnect") == 0) {
      serial_port_.Close();
      result->Success(flutter::EncodableValue(true));
    } else if (method_call.method_name().compare("write") == 0) {
      const auto* arguments = std::get_if<std::vector<uint8_t>>(method_call.arguments());
      if (arguments) {
        result->Success(flutter::EncodableValue(serial_port_.Write(*arguments)));
      } else {
        result->Error("InvalidArguments", "Invalid arguments for write");
      }
    } else if (method_call.method_name().compare("read") == 0) {
      auto data = serial_port_.Read();
      result->Success(flutter::EncodableValue(data));
    } else if (method_call.method_name().compare("listDevices") == 0) {
      // Implement device listing logic here
      // This is a placeholder implementation
      flutter::EncodableList devices;
      // Add logic to populate the devices list
      result->Success(flutter::EncodableValue(devices));
    } else {
      result->NotImplemented();
    }
  }
};

void SerialComPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  SerialComPlugin::RegisterWithRegistrar(registrar);
}

}  // namespace serial_com
